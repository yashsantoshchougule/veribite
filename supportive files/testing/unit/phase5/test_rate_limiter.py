"""Unit and integration tests for Multi-Tier Sliding-Window Rate Limiter and Middleware."""

import time
from fastapi.testclient import TestClient
import pytest

from backend.core.rate_limiter import (
    InMemoryRateLimiter,
    RateLimitTier,
    RateLimiter,
    get_rate_limiter,
    get_tier_for_path,
    set_rate_limiter,
    TIER_ADVISOR,
    TIER_AUTH,
    TIER_DEFAULT,
    TIER_EXEMPT,
    TIER_PRODUCTS,
    TIER_VISION,
)
from backend.main import app


@pytest.fixture(autouse=True)
def reset_global_limiter():
    """Reset rate limiter state before each test."""
    limiter = RateLimiter()
    set_rate_limiter(limiter)
    yield
    limiter.reset()


def test_tier_mapping_for_endpoints():
    """Verify endpoint paths map strictly to the intended rate limiting tiers."""
    assert get_tier_for_path("/health") == TIER_EXEMPT
    assert get_tier_for_path("/docs") == TIER_EXEMPT
    assert get_tier_for_path("/openapi.json") == TIER_EXEMPT

    assert get_tier_for_path("/api/v1/advisor/chat") == TIER_ADVISOR
    assert TIER_ADVISOR.max_requests == 4
    assert TIER_ADVISOR.window_seconds == 60
    assert get_tier_for_path("/api/v1/scan/vision") == TIER_VISION
    assert get_tier_for_path("/api/v1/product/8901030000000") == TIER_PRODUCTS
    assert get_tier_for_path("/api/v1/auth/verify-token") == TIER_AUTH
    assert get_tier_for_path("/api/v1/unknown") == TIER_DEFAULT


def test_in_memory_sliding_window_consumption():
    """Verify in-memory sliding window accurately tracks quota, remaining count, and reset."""
    limiter = InMemoryRateLimiter()
    tier = RateLimitTier(name="test_tier", max_requests=3, window_seconds=60)
    client_ip = "192.168.1.10"

    t0 = 1000.0

    # Request 1
    allowed, limit, remaining, reset_sec = limiter.check_and_consume(client_ip, tier, current_time=t0)
    assert allowed is True
    assert limit == 3
    assert remaining == 2
    assert reset_sec == 60

    # Request 2
    allowed, limit, remaining, reset_sec = limiter.check_and_consume(client_ip, tier, current_time=t0 + 5)
    assert allowed is True
    assert remaining == 1

    # Request 3
    allowed, limit, remaining, reset_sec = limiter.check_and_consume(client_ip, tier, current_time=t0 + 10)
    assert allowed is True
    assert remaining == 0

    # Request 4 (Should be blocked)
    allowed, limit, remaining, reset_sec = limiter.check_and_consume(client_ip, tier, current_time=t0 + 15)
    assert allowed is False
    assert remaining == 0
    # Window resets 60s after request 1 (1000 + 60 - 1015 = 45s)
    assert reset_sec == 45


def test_sliding_window_expiration_and_recovery():
    """Verify expired timestamps roll off and restore available quota."""
    limiter = InMemoryRateLimiter()
    tier = RateLimitTier(name="test_tier", max_requests=2, window_seconds=30)
    client_ip = "10.0.0.1"

    t0 = 2000.0
    limiter.check_and_consume(client_ip, tier, current_time=t0)
    limiter.check_and_consume(client_ip, tier, current_time=t0 + 5)

    # Quota full
    allowed, _, _, _ = limiter.check_and_consume(client_ip, tier, current_time=t0 + 10)
    assert allowed is False

    # Advance time past t0 + 30 (31 seconds later)
    # The first timestamp (t0) is now expired, leaving only 1 active timestamp
    allowed, limit, remaining, _ = limiter.check_and_consume(client_ip, tier, current_time=t0 + 31)
    assert allowed is True
    assert remaining == 0


def test_client_ip_isolation():
    """Verify separate client IPs maintain independent quotas."""
    limiter = InMemoryRateLimiter()
    tier = RateLimitTier(name="test_tier", max_requests=1, window_seconds=60)

    # Client A consumes its token
    allowed_a, _, remaining_a, _ = limiter.check_and_consume("1.1.1.1", tier)
    assert allowed_a is True
    assert remaining_a == 0

    # Client A is now blocked
    blocked_a, _, _, _ = limiter.check_and_consume("1.1.1.1", tier)
    assert blocked_a is False

    # Client B should still have full quota
    allowed_b, _, remaining_b, _ = limiter.check_and_consume("2.2.2.2", tier)
    assert allowed_b is True
    assert remaining_b == 0


def test_middleware_attaches_ratelimit_headers():
    """Verify FastAPI middleware injects standard X-RateLimit headers on responses."""
    client = TestClient(app)

    response = client.get("/health")
    # Health endpoint is exempt
    assert response.status_code == 200

    # Calling an active route returns X-RateLimit-* headers
    response = client.get("/api/v1/product/invalid-code")
    assert "X-RateLimit-Limit" in response.headers
    assert "X-RateLimit-Remaining" in response.headers
    assert "X-RateLimit-Reset" in response.headers
    assert response.headers["X-RateLimit-Limit"] == "60"


def test_middleware_returns_429_when_exceeded():
    """Verify middleware rejects excess traffic with HTTP 429 and Retry-After header."""
    # Create custom low-quota limiter for testing fast trigger
    test_limiter = RateLimiter()
    set_rate_limiter(test_limiter)
    client = TestClient(app)

    # Pre-consume all tokens for client '192.168.1.50' under auth tier
    client_ip = "192.168.1.50"
    for _ in range(TIER_AUTH.max_requests):
        test_limiter.check_rate_limit(f"ip:{client_ip}", TIER_AUTH)

    # Next request from this IP must trigger 429
    response = client.post(
        "/api/v1/auth/verify-token",
        json={"token": "mock_valid_token"},
        headers={"X-Forwarded-For": client_ip},
    )

    assert response.status_code == 429
    assert "Retry-After" in response.headers
    assert response.headers["X-RateLimit-Remaining"] == "0"
    data = response.json()
    assert "Rate limit exceeded" in data["detail"]
    assert data["tier"] == "auth"
    assert data["retry_after"] > 0


def test_middleware_per_user_isolation():
    """Verify separate users on the SAME IP address maintain independent quotas."""
    test_limiter = RateLimiter()
    set_rate_limiter(test_limiter)
    client = TestClient(app)

    shared_ip = "192.168.1.100"

    # User 1 pre-consumes all 4 allowed requests under advisor tier
    for _ in range(TIER_ADVISOR.max_requests):
        test_limiter.check_rate_limit("user:user_alpha", TIER_ADVISOR)

    # User 1's next request from shared_ip is rejected with 429
    from unittest.mock import patch
    with patch("backend.api.advisor.call_gemini_advisor", return_value="OK"):
        resp_user1 = client.post(
            "/api/v1/advisor/chat",
            json={
                "product_data": {"product_name": "Test Snack", "nutrition": {}, "additives": []},
                "user_guardrails": {"weight_kg": 65.0},
                "user_message": "Is this safe?",
            },
            headers={"X-Forwarded-For": shared_ip, "X-User-Id": "user_alpha"},
        )
        assert resp_user1.status_code == 429

        # User 2 from the exact SAME shared_ip has full quota and succeeds
        resp_user2 = client.post(
            "/api/v1/advisor/chat",
            json={
                "product_data": {"product_name": "Test Snack", "nutrition": {}, "additives": []},
                "user_guardrails": {"weight_kg": 65.0},
                "user_message": "Is this safe?",
            },
            headers={"X-Forwarded-For": shared_ip, "X-User-Id": "user_beta"},
        )
        assert resp_user2.status_code == 200
        assert resp_user2.headers["X-RateLimit-Limit"] == "4"
        assert resp_user2.headers["X-RateLimit-Remaining"] == "3"


def test_health_check_is_always_exempt():
    """Verify health probe is never throttled even after massive request volume."""
    client = TestClient(app)
    for _ in range(100):
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

