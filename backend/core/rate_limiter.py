"""Production-grade multi-tier sliding-window rate limiting engine for FastAPI.

Provides token-bucket sliding-window rate tracking across distinct API tiers:
- AI Advisor Chat (/api/v1/advisor/*): 4 req/min
- Cloud Vision OCR (/api/v1/scan/vision): 10 req/min
- Product Barcode Resolution (/api/v1/product/*): 60 req/min
- Authentication (/api/v1/auth/*): 20 req/min
- Default API: 60 req/min
- Health probes (/health, /docs, /openapi.json): Exempt (Unlimited)

Dual-mode storage:
- High-throughput distributed Redis backend when Redis is online.
- Thread-safe zero-dependency in-memory sliding-window log as resilient default/fallback.
"""

from collections import deque
from dataclasses import dataclass
import hashlib
import logging
import os
import threading
import time
from typing import Any, Dict, Optional, Tuple

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse, Response

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class RateLimitTier:
    """Rate limit configuration for an endpoint group."""
    name: str
    max_requests: int
    window_seconds: int


# Pre-defined rate limiting tiers
TIER_ADVISOR = RateLimitTier(name="advisor", max_requests=4, window_seconds=60)
TIER_VISION = RateLimitTier(name="vision", max_requests=10, window_seconds=60)
TIER_PRODUCTS = RateLimitTier(name="products", max_requests=60, window_seconds=60)
TIER_AUTH = RateLimitTier(name="auth", max_requests=20, window_seconds=60)
TIER_DEFAULT = RateLimitTier(name="default", max_requests=60, window_seconds=60)
TIER_EXEMPT = RateLimitTier(name="exempt", max_requests=0, window_seconds=0)


def get_tier_for_path(path: str) -> RateLimitTier:
    """Map incoming request URL path to its designated rate limit tier."""
    normalized = path.rstrip("/") if path != "/" else "/"
    if normalized in ("/health", "/docs", "/openapi.json", "/redoc") or normalized.startswith(("/docs/", "/static/")):
        return TIER_EXEMPT
    if normalized.startswith("/api/v1/advisor"):
        return TIER_ADVISOR
    if normalized.startswith("/api/v1/scan/vision"):
        return TIER_VISION
    if normalized.startswith("/api/v1/product"):
        return TIER_PRODUCTS
    if normalized.startswith("/api/v1/auth"):
        return TIER_AUTH
    return TIER_DEFAULT


class InMemoryRateLimiter:
    """Thread-safe sliding-window rate limiter using timestamp deques."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._store: Dict[str, deque] = {}

    def check_and_consume(
        self, client_id: str, tier: RateLimitTier, current_time: Optional[float] = None
    ) -> Tuple[bool, int, int, int]:
        """Check quota and consume one token if available.

        Returns:
            Tuple of (allowed: bool, limit: int, remaining: int, reset_seconds: int)
        """
        if tier.window_seconds <= 0 or tier.max_requests <= 0:
            return True, 0, 0, 0

        now = current_time if current_time is not None else time.time()
        key = f"{tier.name}:{client_id}"
        cutoff = now - tier.window_seconds

        with self._lock:
            timestamps = self._store.setdefault(key, deque())

            # Prune timestamps outside current window
            while timestamps and timestamps[0] <= cutoff:
                timestamps.popleft()

            count = len(timestamps)
            if count >= tier.max_requests:
                oldest = timestamps[0]
                reset_sec = max(1, int(oldest + tier.window_seconds - now))
                return False, tier.max_requests, 0, reset_sec

            # Record this request
            timestamps.append(now)
            remaining = tier.max_requests - (count + 1)
            oldest = timestamps[0]
            reset_sec = max(1, int(oldest + tier.window_seconds - now))
            return True, tier.max_requests, remaining, reset_sec

    def reset(self, client_id: Optional[str] = None) -> None:
        """Clear rate limit entries (for testing or administrative reset)."""
        with self._lock:
            if client_id is None:
                self._store.clear()
            else:
                keys_to_remove = [k for k in self._store if k.endswith(f":{client_id}")]
                for k in keys_to_remove:
                    self._store.pop(k, None)


class RedisRateLimiter:
    """Sliding-window rate limiter backed by Redis sorted sets (ZADD/ZCARD)."""

    def __init__(self, redis_client: Any) -> None:
        self.redis = redis_client

    def check_and_consume(
        self, client_id: str, tier: RateLimitTier, current_time: Optional[float] = None
    ) -> Tuple[bool, int, int, int]:
        if tier.window_seconds <= 0 or tier.max_requests <= 0:
            return True, 0, 0, 0

        now = current_time if current_time is not None else time.time()
        key = f"ratelimit:{tier.name}:{client_id}"
        cutoff = now - tier.window_seconds

        pipe = self.redis.pipeline()
        pipe.zremrangebyscore(key, "-inf", cutoff)
        pipe.zcard(key)
        pipe.zrange(key, 0, 0, withscores=True)
        results = pipe.execute()

        current_count = results[1]
        oldest_records = results[2]

        if current_count >= tier.max_requests:
            oldest_score = oldest_records[0][1] if oldest_records else now
            reset_sec = max(1, int(oldest_score + tier.window_seconds - now))
            return False, tier.max_requests, 0, reset_sec

        member = f"{now}-{time.perf_counter()}"
        pipe2 = self.redis.pipeline()
        pipe2.zadd(key, {member: now})
        pipe2.expire(key, tier.window_seconds + 5)
        pipe2.execute()

        remaining = tier.max_requests - (current_count + 1)
        oldest_score = oldest_records[0][1] if oldest_records else now
        reset_sec = max(1, int(oldest_score + tier.window_seconds - now))
        return True, tier.max_requests, remaining, reset_sec


class RateLimiter:
    """Unified Rate Limiter with automatic Redis detection and memory fallback."""

    def __init__(self, redis_client: Optional[Any] = None) -> None:
        self.in_memory = InMemoryRateLimiter()
        self.redis_limiter: Optional[RedisRateLimiter] = (
            RedisRateLimiter(redis_client) if redis_client is not None else None
        )

    def check_rate_limit(
        self, client_id: str, tier: RateLimitTier, current_time: Optional[float] = None
    ) -> Tuple[bool, int, int, int]:
        if self.redis_limiter is not None:
            try:
                return self.redis_limiter.check_and_consume(client_id, tier, current_time)
            except Exception as e:
                logger.warning(f"Redis rate check failed ({e}). Falling back to in-memory limiter.")

        return self.in_memory.check_and_consume(client_id, tier, current_time)

    def reset(self, client_id: Optional[str] = None) -> None:
        self.in_memory.reset(client_id)


# Global default rate limiter instance
_default_rate_limiter: Optional[RateLimiter] = None


def get_rate_limiter() -> RateLimiter:
    """Return singleton RateLimiter instance."""
    global _default_rate_limiter
    if _default_rate_limiter is None:
        _default_rate_limiter = RateLimiter()
    return _default_rate_limiter


def set_rate_limiter(limiter: RateLimiter) -> None:
    """Override singleton RateLimiter (useful in tests or startup)."""
    global _default_rate_limiter
    _default_rate_limiter = limiter


class RateLimitMiddleware(BaseHTTPMiddleware):
    """FastAPI/Starlette middleware enforcing multi-tier rate limiting."""

    def __init__(self, app: Any, limiter: Optional[RateLimiter] = None) -> None:
        super().__init__(app)
        self._custom_limiter = limiter

    @property
    def limiter(self) -> RateLimiter:
        return self._custom_limiter if self._custom_limiter is not None else get_rate_limiter()

    def _extract_client_identifier(self, request: Request) -> str:
        """Extract per-user identifier (X-User-Id, Bearer token) or fallback to client IP."""
        # 1. Direct user identifier header
        user_id = request.headers.get("x-user-id") or request.headers.get("user-id")
        if user_id and user_id.strip():
            return f"user:{user_id.strip()}"

        # 2. Bearer Authorization token fingerprint
        auth_header = request.headers.get("authorization")
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header[7:].strip()
            if token:
                return f"user:{hashlib.sha256(token.encode('utf-8')).hexdigest()[:16]}"

        # 3. Fallback to client IP address for guest/unauthenticated traffic
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return f"ip:{forwarded.split(',')[0].strip()}"
        if request.client and request.client.host:
            return f"ip:{request.client.host}"
        return "ip:127.0.0.1"

    async def dispatch(self, request: Request, call_next: Any) -> Response:
        tier = get_tier_for_path(request.url.path)
        if tier.name == "exempt":
            return await call_next(request)

        client_id = self._extract_client_identifier(request)
        allowed, limit, remaining, reset_sec = self.limiter.check_rate_limit(client_id, tier)

        if not allowed:
            headers = {
                "Retry-After": str(reset_sec),
                "X-RateLimit-Limit": str(limit),
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": str(reset_sec),
            }
            return JSONResponse(
                status_code=429,
                content={
                    "detail": f"Rate limit exceeded for {tier.name} tier. Please wait {reset_sec} seconds before retrying.",
                    "retry_after": reset_sec,
                    "tier": tier.name,
                },
                headers=headers,
            )

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset_sec)
        return response
