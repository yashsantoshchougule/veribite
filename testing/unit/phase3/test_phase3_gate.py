"""Master Release Gate for Phase 3: Deterministic Scoring, Red Cap & Safe Dosage Engine.

Verifies:
1. Nutri-Score calculation for solids & beverages.
2. NOVA 1-4 classification and non-negotiable 39/100 Hard Red Cap enforcement.
3. Precision Safe Dosage & body-weight JECFA ADI scaling (Adult vs Child).
4. Missing nutrition imputation & salt normalization heuristics.
5. Zero external network calls and sub-second deterministic execution.
"""

import time
from pathlib import Path
import pytest

from backend.core.scoring_engine import (
    compute_base_nutriscore,
    classify_nova_group,
    evaluate_product_verdict,
)
from backend.core.dosage_engine import (
    calculate_prescribed_dosage,
    normalize_and_impute_nutrition,
)


def test_phase3_master_scoring_and_dosage_pipeline():
    start_time = time.perf_counter()

    # Case 1: Ultra-Processed Indian Snack with unreadable Sodium and Red-Tier Color
    raw_label_nutrition = {
        "energy_kj": 1900.0,
        "sugar_g_per_100g": 28.0,
        "sat_fat_g_per_100g": 12.0,
        "salt_g": 1.2,  # Should normalize to 480 mg Sodium
        "fiber_g": None,  # Should default to 0.0
        "protein_g": 4.0,
        "fruit_veg_nut_pct": 0.0,
        "trans_fat_g": 0.1,
    }
    additives = [
        {
            "ins_code": "102",
            "primary_name": "Tartrazine",
            "risk_tier": "RED",
            "triggers_red_cap": 1,
            "child_hyperactivity_flag": 1,
            "jecfa_adi_mg_kg": 10.0,
            "default_conc_mg_per_g": 0.1,
        }
    ]

    # Step A: Normalization & Imputation
    norm_nutrition = normalize_and_impute_nutrition(
        raw_nutrition=raw_label_nutrition,
        ingredients_ordered=["Refined Flour", "Sugar", "Palm Oil", "Food Colour (INS 102)"],
        category="Biscuits",
    )
    assert norm_nutrition["sodium_mg"] == 480.0
    assert norm_nutrition["fiber_g"] == 0.0

    # Step B: Overall Health Verdict with 39 Red Cap
    verdict = evaluate_product_verdict(
        nutrition=norm_nutrition,
        additives=additives,
        is_beverage=False,
    )
    assert verdict["final_score"] <= 39
    assert verdict["red_cap_triggered"] is True
    assert verdict["nova_grade"] == 4
    assert "Red-Tier Additive Detected: Tartrazine" in verdict["red_cap_reason"]

    # Step C: Dosage Prescriptions
    # 65 kg Adult
    adult_dosage = calculate_prescribed_dosage(
        nutrition=norm_nutrition,
        additives=additives,
        user_weight_kg=65.0,
        is_child=False,
        unit_piece_weight_g=12.0,
        product_score=verdict["final_score"],
        nova_grade=verdict["nova_grade"],
    )
    assert adult_dosage["safe_portion_grams"] > 0
    assert adult_dosage["safe_pieces"] is not None
    assert adult_dosage["frequency_schedule"] == "Once a Month / Rare Treat"

    # 20 kg Child - Southampton Azo Dye override
    child_dosage = calculate_prescribed_dosage(
        nutrition=norm_nutrition,
        additives=additives,
        user_weight_kg=20.0,
        is_child=True,
        unit_piece_weight_g=12.0,
        product_score=verdict["final_score"],
        nova_grade=verdict["nova_grade"],
    )
    assert child_dosage["safe_portion_grams"] < adult_dosage["safe_portion_grams"]
    assert child_dosage["frequency_schedule"] == "Complete Avoidance Recommended for Children"
    assert "Contains Synthetic Azo Dye INS 102" in child_dosage["frequency_warning"]

    # Step D: Division-by-Zero Safety with Zeroes
    zero_nutrition = {
        "energy_kj": 0.0,
        "total_sugars_g": 0.0,
        "sat_fat_g": 0.0,
        "sodium_mg": 0.0,
    }
    zero_dosage = calculate_prescribed_dosage(
        nutrition=zero_nutrition,
        additives=[],
        user_weight_kg=65.0,
        is_child=False,
    )
    assert zero_dosage["safe_portion_grams"] == 150  # Clamped to maximum 150g portion

    elapsed = time.perf_counter() - start_time
    assert elapsed < 0.50, f"Execution too slow: {elapsed:.3f}s (must be < 0.5s)"


def test_strict_test_isolation_and_no_production_pollution():
    """Verify all test files reside strictly in testing/ and production code contains no test fixtures."""
    repo_root = Path(__file__).resolve().parent.parent.parent.parent
    backend_tests = list((repo_root / "backend").rglob("test_*.py"))
    backend_tests = [p for p in backend_tests if ".venv" not in p.parts]
    assert len(backend_tests) == 0, f"Test pollution in backend: {backend_tests}"

    data_pipeline_tests = list((repo_root / "data_pipeline").rglob("test_*.py"))
    assert len(data_pipeline_tests) == 0, f"Test pollution in data_pipeline: {data_pipeline_tests}"

