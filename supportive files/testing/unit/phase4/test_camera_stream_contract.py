"""Release Gate Contract Tests for Phase 4 Smart Camera and 3-Tier Pipeline."""

import time
import pytest
from backend.core.barcode_normalizer import validate_and_normalize_barcode
from backend.core.ocr_parser import detect_specular_glare, parse_ocr_nutrition_table
from backend.core.dosage_engine import normalize_and_impute_nutrition


def test_smart_camera_barcode_and_glare_contract():
    start_time = time.perf_counter()

    # 1. Barcode normalization & check-digit verification
    barcode = "8901030383786"
    assert validate_and_normalize_barcode(barcode) == barcode
    assert validate_and_normalize_barcode("invalid_123") is None

    # 2. Specular foil glare detection contract
    # Saturated pixels above 18% must raise glare flag
    saturated = [255] * 20 + [100] * 80  # 20% > 18%
    glare = detect_specular_glare(saturated)
    assert glare["is_glare"] is True
    assert "Foil Glare Detected" in glare["badge"]

    # 3. Quick Macro Slider contract normalization
    slider_input = {
        "sugar_g_per_100g": 18.0,
        "sat_fat_g_per_100g": 7.5,
        "sodium_mg_per_100g": 320.0,
    }
    norm = normalize_and_impute_nutrition(slider_input)
    assert norm["total_sugars_g"] == 18.0
    assert norm["sat_fat_g"] == 7.5
    assert norm["sodium_mg"] == 320.0

    elapsed = time.perf_counter() - start_time
    assert elapsed < 0.20, f"Contract test too slow: {elapsed:.3f}s"
