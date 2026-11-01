"""Unit tests for Partial Tier 1 detection and status code contract."""

from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)


def test_partial_tier1_returns_prefilled_nutrition_and_ocr_prompt():
    mock_partial_off_response = {
        "status": 1,
        "product": {
            "product_name": "Mixed Fruit Juice",
            "brands": "Tropic Delight",
            "categories": "Beverages",
            "ingredients_text": "",  # Empty ingredients text triggers PARTIAL_TIER_1
            "nutriments": {
                "energy-kj_100g": 220.0,
                "sugars_100g": 11.5,
                "saturated-fat_100g": 0.0,
                "sodium_100g": 0.02,
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
        mock_http_resp.json.return_value = mock_partial_off_response
        mock_get.return_value = mock_http_resp

        response = client.get("/api/v1/product/8901030383786")
        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "PARTIAL_TIER_1"
        assert data["requires_ocr_ingredient_scan"] is True
        assert data["product_name"] == "Mixed Fruit Juice"
        assert data["nutrition"]["total_sugars_g"] == 11.5
        assert "scan ingredients list" in data["message"].lower()
