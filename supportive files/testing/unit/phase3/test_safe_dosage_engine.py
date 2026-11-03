"""Unit tests for precision safe consumption dosage and body-weight JECFA ADI scaling engine."""

import pytest
from backend.core.dosage_engine import calculate_prescribed_dosage


def test_popular_indian_orange_cream_biscuit_worked_example():
    # 100g pack, 10g per biscuit
    # Sugar = 32g (0.32 g/g), Sat-Fat = 14g (0.14 g/g), Sodium = 220mg (2.2 mg/g)
    # INS 110: JECFA ADI = 4.0 mg/kg, default conc = 0.1 mg/g
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

    # 1. 65 kg Adult Profile
    adult_dosage = calculate_prescribed_dosage(
        nutrition=nutrition,
        additives=additives,
        user_weight_kg=65.0,
        is_child=False,
        unit_piece_weight_g=10.0,
    )
    # Sugar ceiling: 5.0 / 0.32 = 15.625g. Sat-Fat: 4.0 / 0.14 = 28.57g. Sodium: 400 / 2.2 = 181.8g.
    # Base macro portion = 15.625g -> 16g rounded
    assert adult_dosage["safe_portion_grams"] == 16
    assert adult_dosage["safe_pieces"] == 1
    assert adult_dosage["limiting_factor"] == "Sugar"
    assert adult_dosage["frequency_schedule"] == "Once a Month / Rare Treat"

    # 2. 20 kg Child Profile Switch
    child_dosage = calculate_prescribed_dosage(
        nutrition=nutrition,
        additives=additives,
        user_weight_kg=20.0,
        is_child=True,
        unit_piece_weight_g=10.0,
    )
    # Scaling to 20kg: 15.625 * (20 / 65) = 4.8g -> 5g
    assert child_dosage["safe_portion_grams"] == 5
    assert child_dosage["safe_pieces"] == 0  # 4.8 / 10 = 0 full pieces (Max 0.5 biscuit)
    assert child_dosage["frequency_schedule"] == "Complete Avoidance Recommended for Children"
    assert "Contains Synthetic Azo Dye INS 110" in child_dosage["frequency_warning"]


def test_clean_food_dosage_clamping():
    # Very clean food (e.g. apple or cucumber) where sugar, sat fat, sodium are very low
    nutrition = {
        "sugar_g_per_100g": 0.5,
        "sat_fat_g_per_100g": 0.0,
        "sodium_mg_per_100g": 5.0,
    }
    additives = []
    dosage = calculate_prescribed_dosage(
        nutrition=nutrition,
        additives=additives,
        user_weight_kg=65.0,
        is_child=False,
    )
    # Mathematical portion would be 1000g, but single snack portion is clamped to <= 150g
    assert dosage["safe_portion_grams"] == 150
    assert dosage["frequency_schedule"] == "Daily Safe"

