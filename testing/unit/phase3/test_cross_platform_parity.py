"""Cross-platform parity tests verifying Python and Dart mathematical equivalence."""

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


def test_parity_whole_grain_oats():
    # Exact case from mobile_app/test/scoring_engine_test.dart
    nutrition = {
        "energy_kj": 1550.0,
        "total_sugars_g": 1.0,
        "sat_fat_g": 1.2,
        "sodium_mg": 5.0,
        "fiber_g": 10.0,
        "protein_g": 13.0,
        "fruit_veg_nut_pct": 0.0,
    }
    score = compute_base_nutriscore(nutrition, is_beverage=False)
    assert score == 82


def test_parity_red_azo_dye_cap():
    # Exact case from mobile_app/test/scoring_engine_test.dart
    nutrition = {
        "energy_kj": 1500.0,
        "total_sugars_g": 5.0,
        "sat_fat_g": 0.5,
        "sodium_mg": 100.0,
        "fiber_g": 8.0,
        "protein_g": 10.0,
        "fruit_veg_nut_pct": 50.0,
        "trans_fat_g": 0.0,
    }
    additives = [
        {
            "ins_code": "102",
            "primary_name": "Tartrazine",
            "risk_tier": "RED",
            "triggers_red_cap": 1,
            "child_hyperactivity_flag": 1,
        }
    ]
    verdict = evaluate_product_verdict(nutrition, additives, is_beverage=False)
    assert verdict["final_score"] <= 39
    assert verdict["red_cap_triggered"] is True
    assert verdict["nova_grade"] == 4
    assert "Red-Tier Additive Detected" in verdict["red_cap_reason"]


def test_parity_orange_cream_biscuit_worked_example():
    # Exact case from mobile_app/test/scoring_engine_test.dart
    nutrition = {
        "sugar_g_per_100g": 32.0,
        "sat_fat_g_per_100g": 14.0,
        "sodium_mg_per_100g": 220.0,
    }
    additives = [
        {
            "ins_code": "110",
            "primary_name": "Sunset Yellow FCF",
            "risk_tier": "RED",
            "jecfa_adi_mg_kg": 4.0,
            "default_conc_mg_per_g": 0.1,
            "child_hyperactivity_flag": 1,
        }
    ]

    # Adult
    adult = calculate_prescribed_dosage(
        nutrition=nutrition,
        additives=additives,
        user_weight_kg=65.0,
        is_child=False,
        unit_piece_weight_g=10.0,
    )
    assert adult["safe_portion_grams"] == 16
    assert adult["safe_pieces"] == 1
    assert adult["limiting_factor"] == "Sugar"
    assert adult["frequency_schedule"] == "Once a Month / Rare Treat"

    # Child
    child = calculate_prescribed_dosage(
        nutrition=nutrition,
        additives=additives,
        user_weight_kg=20.0,
        is_child=True,
        unit_piece_weight_g=10.0,
    )
    assert child["safe_portion_grams"] == 5
    assert child["safe_pieces"] == 0
    assert child["frequency_schedule"] == "Complete Avoidance Recommended for Children"
    assert "Contains Synthetic Azo Dye INS 110" in child["frequency_warning"]


def test_parity_salt_to_sodium_normalization():
    # Exact case from mobile_app/test/scoring_engine_test.dart
    raw = {"salt_g": 1.5, "sodium_mg": None}
    norm = normalize_and_impute_nutrition(raw_nutrition=raw)
    assert norm["sodium_mg"] == 600.0
