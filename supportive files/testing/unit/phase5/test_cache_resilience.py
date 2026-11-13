"""Unit tests for multi-layer cache resilience (Redis -> SQLite fallback)."""

import time
from unittest.mock import MagicMock, patch
import pytest
from backend.services.cache_service import MultiLayerCacheManager
from backend.core.product_cache import LocalProductCache


def test_redis_connection_error_falls_back_to_sqlite(tmp_path):
    db_file = tmp_path / "fallback_cache.db"
    sqlite_cache = LocalProductCache(db_path=str(db_file))
    sqlite_cache.init_table()

    # Pre-seed SQLite cache
    product_data = {
        "barcode": "8901030383786",
        "product_name": "Orange Cream Biscuits",
        "brand_name": "Britannia",
        "category": "Biscuits",
        "serving_size_g": 20.0,
        "piece_weight_g": 10.0,
        "nutrition_json": '{"sugar_g_per_100g": 32.0, "sat_fat_g_per_100g": 14.0}',
        "additives_json": '[{"ins_code": "110", "risk_tier": "RED"}]',
        "health_score": 22,
        "nova_grade": 4,
        "red_cap_triggered": 1,
        "ingredient_hash": "testhash",
    }
    sqlite_cache.set_product(product_data)

    # Mock Redis client that fails with connection error
    mock_redis = MagicMock()
    mock_redis.get.side_effect = ConnectionError("Redis server unreachable")

    manager = MultiLayerCacheManager(redis_client=mock_redis, sqlite_cache=sqlite_cache)

    start = time.perf_counter()
    retrieved = manager.get_product("8901030383786")
    elapsed = time.perf_counter() - start

    assert retrieved is not None
    assert retrieved["product_name"] == "Orange Cream Biscuits"
    assert retrieved["source"] == "sqlite_fallback"
    assert elapsed < 0.050, f"Fallback took {elapsed:.4f}s; must be < 50ms"


def test_redis_hit_bypasses_sqlite(tmp_path):
    db_file = tmp_path / "unused.db"
    sqlite_cache = LocalProductCache(db_path=str(db_file))

    mock_redis = MagicMock()
    mock_redis.get.return_value = '{"product_name": "Cached In Redis", "health_score": 85}'

    manager = MultiLayerCacheManager(redis_client=mock_redis, sqlite_cache=sqlite_cache)
    retrieved = manager.get_product("8901030383786")

    assert retrieved is not None
    assert retrieved["product_name"] == "Cached In Redis"
    assert retrieved["source"] == "redis"
