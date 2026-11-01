"""Unit tests for Tier 1 Barcode lookup API endpoint and Open Food Facts enrichment proxy."""

from unittest.mock import patch, MagicMock
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.core.product_cache import LocalProductCache

client = TestClient(app)


def test_tier1_invalid_barcode_returns_400():
    response = client.get("/api/v1/product/invalid_barcode_123")
    assert response.status_code == 400
    assert "Invalid barcode format" in response.json()["detail"]


def test_tier1_cache_hit_returns_sub_20ms(tmp_path):
    # Pre-seed cache
    db_file = tmp_path / "test_api_cache.db"
    cache = LocalProductCache(db_path=str(db_file))
    cache.init_table()
    cache.set_product({
        "barcode": "8901030383786",
        "product_name": "Orange Cream Biscuits",
        "brand_name": "Britannia",
        "category": "Biscuits",
        "serving_size_g": 20.0,
        "piece_weight_g": 10.0,
        "nutrition_json": '{"sugar_g_per_100g": 32.0, "sat_fat_g_per_100g": 14.0, "sodium_mg_per_100g": 220.0}',
        "additives_json": '[{"ins_code": "110", "primary_name": "Sunset Yellow FCF", "risk_tier": "RED", "triggers_red_cap": 1}]',
        "health_score": 22,
        "nova_grade": 4,
        "red_cap_triggered": 1,
        "ingredient_hash": "mockhash123",
    })

    with patch("backend.api.products.get_product_cache", return_value=cache):
        response = client.get("/api/v1/product/8901030383786")
        assert response.status_code == 200
        data = response.json()
        assert data["source"] == "cache"
        assert data["product_name"] == "Orange Cream Biscuits"
        assert data["health_score"] == 22
        assert data["red_cap_triggered"] is True


def test_tier1_openfoodfacts_enrichment_flow():
    mock_off_response = {
        "status": 1,
        "product": {
            "product_name": "Whole Wheat Bread",
            "brands": "Healthy Bakery",
            "categories": "Plant-based foods",
            "ingredients_text": "Whole wheat flour, water, yeast, salt, vegetable oil.",
            "nutriments": {
                "energy-kj_100g": 1050.0,
                "sugars_100g": 3.0,
                "saturated-fat_100g": 0.8,
                "sodium_100g": 0.45,  # 0.45g = 450mg
                "fiber_100g": 6.5,
                "proteins_100g": 9.0,
            },
        },
    }

    with patch("httpx.AsyncClient.get") as mock_get, \
         patch("backend.api.products.get_product_cache") as mock_cache_getter:
        
        mock_cache = MagicMock()
        mock_cache.get_product.return_value = None  # Cache miss
        mock_cache_getter.return_value = mock_cache

        mock_http_resp = MagicMock()
        mock_http_resp.status_code = 200
        mock_http_resp.json.return_value = mock_off_response
        mock_get.return_value = mock_http_resp

        response = client.get("/api/v1/product/8901030383786")
        assert response.status_code == 200
        data = response.json()
        assert data["source"] == "openfoodfacts"
        assert data["product_name"] == "Whole Wheat Bread"
        assert data["health_score"] >= 75
        assert data["red_cap_triggered"] is False
        assert mock_cache.set_product.called

