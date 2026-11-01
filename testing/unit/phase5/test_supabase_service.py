"""Unit tests for Supabase PostgreSQL persistence and multi-layer cache integration."""

import os
from unittest.mock import MagicMock, patch
import pytest

from backend.services.supabase_service import SupabaseProductService
from backend.services.cache_service import MultiLayerCacheManager
from backend.core.product_cache import LocalProductCache


def test_supabase_service_unconfigured_graceful_noop():
    """Verify service does not crash when Supabase environment variables are missing."""
    with patch.dict(os.environ, {}, clear=True):
        service = SupabaseProductService()
        assert service.client is None
        assert service.get_product("8901030383786") is None
        assert service.upsert_product({"barcode": "8901030383786"}) is False


def test_supabase_service_get_and_upsert_success():
    """Verify product retrieval and upserting via Supabase client."""
    mock_client = MagicMock()
    mock_table = MagicMock()
    mock_select = MagicMock()
    mock_eq = MagicMock()
    mock_execute = MagicMock()

    mock_client.table.return_value = mock_table
    mock_table.select.return_value = mock_select
    mock_select.eq.return_value = mock_eq
    mock_eq.execute.return_value = MagicMock(data=[{
        "barcode": "8901030383786",
        "product_name": "Orange Cream Biscuits",
        "health_score": 22,
    }])

    service = SupabaseProductService(client=mock_client)
    product = service.get_product("8901030383786")

    assert product is not None
    assert product["product_name"] == "Orange Cream Biscuits"
    assert product["health_score"] == 22

    # Test upsert
    mock_upsert = MagicMock()
    mock_table.upsert.return_value = mock_upsert
    mock_upsert.execute.return_value = MagicMock(data=[{"barcode": "8901030383786"}])

    ok = service.upsert_product({
        "barcode": "8901030383786",
        "product_name": "Orange Cream Biscuits",
    })
    assert ok is True


def test_cache_manager_with_supabase_tier(tmp_path):
    """Verify MultiLayerCacheManager checks Supabase when Redis fails and SQLite misses."""
    db_file = tmp_path / "sqlite_test.db"
    sqlite_cache = LocalProductCache(db_path=str(db_file))
    sqlite_cache.init_table()

    broken_redis = MagicMock()
    broken_redis.get.side_effect = Exception("Redis Down")

    mock_supabase = MagicMock()
    mock_supabase.get_product.return_value = {
        "barcode": "8901030383786",
        "product_name": "Cloud Stored Biscuit",
        "health_score": 45,
    }

    mgr = MultiLayerCacheManager(
        redis_client=broken_redis,
        supabase_service=mock_supabase,
        sqlite_cache=sqlite_cache,
    )

    product = mgr.get_product("8901030383786")
    assert product is not None
    assert product["product_name"] == "Cloud Stored Biscuit"
    assert product["source"] == "supabase"
