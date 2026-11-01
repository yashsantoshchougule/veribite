"""Unit tests for NOVA (1-4) classification and strict 39/100 Hard Red Cap enforcement."""

import pytest
from backend.core.scoring_engine import (
    classify_nova_group,
    evaluate_product_verdict,
)


def test_strict_39_red_cap_triggered_by_azo_dye():
    # A fortified breakfast cereal with high vitamins/fiber, but contains INS 102 (Tartrazine)
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
    res = evaluate_product_verdict(nutrition, additives, is_beverage=False)
    assert res["final_score"] <= 39
    assert res["red_cap_triggered"] is True
    assert res["nova_grade"] == 4
    assert "Red-Tier Additive Detected" in res["red_cap_reason"]
    assert "Tartrazine" in res["red_cap_reason"]


def test_strict_39_red_cap_triggered_by_trans_fat():
    nutrition = {
        "energy_kj": 1200.0,
        "total_sugars_g": 2.0,
        "sat_fat_g": 2.0,
        "sodium_mg": 100.0,
        "fiber_g": 2.0,
        "protein_g": 5.0,
        "fruit_veg_nut_pct": 0.0,
        "trans_fat_g": 0.5,  # > 0.2g triggers red cap
    }
    additives = []
    res = evaluate_product_verdict(nutrition, additives, is_beverage=False)
    assert res["final_score"] <= 39
    assert res["red_cap_triggered"] is True
    assert "Trans Fat Exceeds 0.2g" in res["red_cap_reason"]


def test_safe_clean_label_product_nova_and_score():
    # Organic Rolled Oats with 0 additives, 0 trans fat
    nutrition = {
        "energy_kj": 1550.0,
        "total_sugars_g": 1.0,
        "sat_fat_g": 1.2,
        "sodium_mg": 5.0,
        "fiber_g": 10.0,
        "protein_g": 13.0,
        "fruit_veg_nut_pct": 0.0,
        "trans_fat_g": 0.0,
    }
    additives = []
    res = evaluate_product_verdict(
        nutrition,
        additives,
        is_beverage=False,
        ingredient_count=1,
        contains_cosmetic_additives=False,
    )
    assert res["final_score"] == 82
    assert res["red_cap_triggered"] is False
    assert res["nova_grade"] == 1
    assert res["red_cap_reason"] is None


def test_caution_tier_additive_deduction():
    # Product with 1 CAUTION additive (INS 322 Lecithin or INS 412 Guar Gum)
    # Deducts 8 points from base score, but does NOT trigger 39 red cap
    nutrition = {
        "energy_kj": 1550.0,
        "total_sugars_g": 1.0,
        "sat_fat_g": 1.2,
        "sodium_mg": 5.0,
        "fiber_g": 10.0,
        "protein_g": 13.0,
        "fruit_veg_nut_pct": 0.0,
        "trans_fat_g": 0.0,
    }
    additives = [
        {
            "ins_code": "322",
            "primary_name": "Lecithins",
            "risk_tier": "CAUTION",
            "triggers_red_cap": 0,
        }
    ]
    res = evaluate_product_verdict(nutrition, additives, is_beverage=False)
    # Base = 82, Caution deduction = -8, NOVA 4 (due to emulsifier) = -10 -> Net = 64
    assert res["final_score"] == 64
    assert res["red_cap_triggered"] is False
    assert res["nova_grade"] == 4

