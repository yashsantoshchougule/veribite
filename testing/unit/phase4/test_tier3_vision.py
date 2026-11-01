"""Unit tests for Tier 3 Gemini 2.5 Flash Vision contract, API endpoint, and reformulation tracker."""

from unittest.mock import patch, MagicMock
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.core.vision_schema import (
    VisionExtractionSchema,
    compute_ingredient_hash,
    check_reformulation,
)

client = TestClient(app)


def test_vision_extraction_schema_validation():
    valid_payload = {
        "product_name": "Orange Cream Biscuits",
        "brand_name": "Britannia",
        "food_category": "Biscuits",
        "net_weight_g": 100.0,
        "serving_size_g": 20.0,
        "piece_weight_g": 10.0,
        "front_pack_claims": ["Rich Cream", "No Trans Fat"],
        "raw_ingredients_ordered": [
            "Refined Wheat Flour",
            "Sugar",
            "Refined Palm Oil",
            "Invert Sugar Syrup",
            "Food Colour (INS 110)",
        ],
        "declared_ins_codes": ["110"],
        "nutrition_per_100g": {
            "energy_kj": 1900.0,
            "total_sugars_g": 32.0,
            "sat_fat_g": 14.0,
            "trans_fat_g": 0.0,
            "sodium_mg": 220.0,
            "fiber_g": 1.5,
            "protein_g": 4.5,
        },
    }
    schema = VisionExtractionSchema(**valid_payload)
    assert schema.product_name == "Orange Cream Biscuits"
    assert schema.declared_ins_codes == ["110"]
    assert len(schema.raw_ingredients_ordered) == 5


def test_reformulation_detection():
    old_ingredients = "Refined Wheat Flour, Sugar, Palm Oil, Food Colour (INS 110)"
    new_ingredients = "Refined Wheat Flour, Maltitol, Palm Oil, Natural Beta-Carotene"

    old_hash = compute_ingredient_hash(old_ingredients)
    new_hash = compute_ingredient_hash(new_ingredients)

    assert old_hash != new_hash
    assert check_reformulation(cached_hash=old_hash, current_ingredients=new_ingredients) is True
    assert check_reformulation(cached_hash=old_hash, current_ingredients=old_ingredients) is False


def test_tier3_vision_api_endpoint(tmp_path):
    mock_extracted = VisionExtractionSchema(
        product_name="Orange Cream Biscuits",
        brand_name="Britannia",
        food_category="Biscuits",
        net_weight_g=100.0,
        serving_size_g=20.0,
        piece_weight_g=10.0,
        front_pack_claims=["Rich Cream"],
        raw_ingredients_ordered=["Refined Wheat Flour", "Sugar", "Palm Oil", "INS 110"],
        declared_ins_codes=["110"],
        nutrition_per_100g={
            "energy_kj": 1900.0,
            "total_sugars_g": 32.0,
            "sat_fat_g": 14.0,
            "trans_fat_g": 0.0,
            "sodium_mg": 220.0,
        },
    )

    with patch("backend.api.vision.extract_vision_with_gemini", return_value=mock_extracted):
        # Multipart form upload with simulated WebP image
        files = {
            "images": ("frame1.webp", b"RIFFmockwebpdata", "image/webp")
        }
        data = {
            "barcode": "8901030383786"
        }
        response = client.post("/api/v1/scan/vision", data=data, files=files)
        assert response.status_code == 200
        res = response.json()
        assert res["product_name"] == "Orange Cream Biscuits"
        assert res["final_score"] <= 39
        assert res["red_cap_triggered"] is True
        assert res["source"] == "gemini_vision"
