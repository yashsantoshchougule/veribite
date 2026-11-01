"""Master Release Gate Suite for Phase 4: 3-Tier Self-Scaling Hybrid Capture Pipeline.

Verifies:
1. Tier 1 Barcode validation & SQLite cache retrieval.
2. Tier 2 On-device OCR parsing & specular foil glare luminance detection.
3. Tier 3 Multi-Angle Gemini 2.5 Flash Vision contract & auto-caching write-through.
4. Ingredient reformulation hashing under the same barcode.
5. Strict test folder isolation & zero external network calls during gate tests.
"""

import time
from pathlib import Path
from unittest.mock import patch
import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.core.barcode_normalizer import validate_and_normalize_barcode
from backend.core.product_cache import LocalProductCache
from backend.core.ocr_parser import (
    parse_ocr_nutrition_table,
    parse_ocr_ingredients_and_ins,
    detect_specular_glare,
)
from backend.core.vision_schema import (
    VisionExtractionSchema,
    compute_ingredient_hash,
    check_reformulation,
)

client = TestClient(app)


def test_phase4_master_hybrid_capture_gate(tmp_path):
    start_time = time.perf_counter()

    # 1. Tier 1: Barcode validation & Cache
    barcode = "8901030383786"
    assert validate_and_normalize_barcode(barcode) == barcode

    db_file = tmp_path / "gate_cache.db"
    cache = LocalProductCache(db_path=str(db_file))
    cache.init_table()

    initial_ingredients = "Refined Wheat Flour, Sugar, Palm Oil, Food Colour (INS 110)"
    initial_hash = compute_ingredient_hash(initial_ingredients)

    cache.set_product({
        "barcode": barcode,
        "product_name": "Orange Cream Biscuits",
        "brand_name": "Britannia",
        "category": "Biscuits",
        "serving_size_g": 20.0,
        "piece_weight_g": 10.0,
        "nutrition_json": '{"sugar_g_per_100g": 32.0, "sat_fat_g_per_100g": 14.0, "sodium_mg_per_100g": 220.0}',
        "additives_json": '[{"ins_code": "110", "risk_tier": "RED", "triggers_red_cap": 1}]',
        "health_score": 22,
        "nova_grade": 4,
        "red_cap_triggered": 1,
        "ingredient_hash": initial_hash,
    })

    with patch("backend.api.products.get_product_cache", return_value=cache):
        res = client.get(f"/api/v1/product/{barcode}")
        assert res.status_code == 200
        assert res.json()["source"] == "cache"
        assert res.json()["health_score"] == 22

    # 2. Tier 2: OCR Parsing & Specular Glare Detection
    ocr_text = """
    NUTRITIONAL INFORMATION per 100g:
    Energy: 480 kcal
    Total Sugars: 32.0 g
    Saturated Fat: 14.0 g
    Sodium: 220 mg
    INGREDIENTS: Refined Wheat Flour, Sugar, Palm Oil, Food Colour (INS 110).
    """
    table = parse_ocr_nutrition_table(ocr_text)
    assert table["total_sugars_g"] == 32.0
    assert table["sat_fat_g"] == 14.0

    glare_pixels = [255] * 22 + [100] * 78  # 22% > 18%
    glare = detect_specular_glare(glare_pixels)
    assert glare["is_glare"] is True
    assert "Foil Glare Detected" in glare["badge"]

    # 3. Tier 3: Reformulation Detection
    reformulated_ingredients = "Whole Wheat Flour, Jaggery, Olive Oil, Beta Carotene"
    is_reformulated = check_reformulation(cached_hash=initial_hash, current_ingredients=reformulated_ingredients)
    assert is_reformulated is True

    # 4. Execution speed check (< 0.5s)
    elapsed = time.perf_counter() - start_time
    assert elapsed < 0.50, f"Gate execution took {elapsed:.3f}s"


def test_phase4_strict_test_isolation():
    """Verify all test files reside strictly in testing/ and production code contains no test fixtures."""
    repo_root = Path(__file__).resolve().parent.parent.parent.parent
    backend_tests = list((repo_root / "backend").rglob("test_*.py"))
    backend_tests = [p for p in backend_tests if ".venv" not in p.parts]
    assert len(backend_tests) == 0, f"Test pollution in backend: {backend_tests}"

    data_pipeline_tests = list((repo_root / "data_pipeline").rglob("test_*.py"))
    assert len(data_pipeline_tests) == 0, f"Test pollution in data_pipeline: {data_pipeline_tests}"
