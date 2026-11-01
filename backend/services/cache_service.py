"""Multi-layer cache manager (Redis sub-15ms with resilient <50ms SQLite fallback)."""

import json
import logging
from typing import Any, Dict, Optional
import redis

from backend.core.product_cache import LocalProductCache

logger = logging.getLogger(__name__)


class MultiLayerCacheManager:
    """Coordinates fast Redis in-memory lookups and local SQLite cache."""

    def __init__(
        self,
        redis_client: Optional[Any] = None,
        sqlite_cache: Optional[LocalProductCache] = None,
        redis_url: str = "redis://localhost:6379/0",
        socket_timeout_sec: float = 0.050,  # Strict 50ms timeout
    ):
        self.sqlite_cache = sqlite_cache or LocalProductCache()
        self.sqlite_cache.init_table()

        if redis_client is not None:
            self.redis = redis_client
        else:
            try:
                self.redis = redis.Redis.from_url(
                    redis_url,
                    socket_connect_timeout=socket_timeout_sec,
                    socket_timeout=socket_timeout_sec,
                    decode_responses=True,
                )
            except Exception as e:
                logger.warning(f"Failed to initialize Redis client: {e}. Defaulting to SQLite only.")
                self.redis = None

    def get_product(self, barcode: str) -> Optional[Dict[str, Any]]:
        """Retrieve product from Redis (<15ms) or fallback to SQLite (<50ms)."""
        # 1. Try Redis primary layer
        if self.redis is not None:
            try:
                raw_json = self.redis.get(f"product:{barcode}")
                if raw_json:
                    data = json.loads(raw_json)
                    data["source"] = "redis"
                    return data
            except Exception as err:
                logger.warning(f"Redis cache lookup failed ({err}). Falling back to SQLite.")

        # 2. Fallback to SQLite secondary layer
        cached = self.sqlite_cache.get_product(barcode)
        if cached:
            cached["source"] = "sqlite_fallback"
            return cached

        return None

    def set_product(self, product_data: Dict[str, Any], ttl_seconds: int = 604800) -> None:
        """Write product data through to both Redis and SQLite cache."""
        barcode = product_data.get("barcode")
        if not barcode:
            return

        # Write to SQLite
        try:
            self.sqlite_cache.set_product(product_data)
        except Exception as e:
            logger.error(f"SQLite cache write failed: {e}")

        # Write to Redis
        if self.redis is not None:
            try:
                self.redis.set(
                    f"product:{barcode}",
                    json.dumps(product_data),
                    ex=ttl_seconds,
                )
            except Exception as err:
                logger.warning(f"Redis write failed: {err}")
