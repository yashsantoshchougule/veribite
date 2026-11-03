"""Unit tests for deterministic Nutri-Score (0-100) scoring engine."""

import pytest
from backend.core.scoring_engine import (
    compute_base_nutriscore,
    compute_negative_points,
    compute_positive_points,
)


def test_solid_food_base_nutriscore():
    # Healthy whole grain oats per 100g:
    # Energy: 1550 kJ (4 pts), Sugars: 1.0g (0 pts), Sat-Fat: 1.2g (1 pt), Sodium: 5mg (0 pts) -> N = 5
    # Fiber: 10.0g (5 pts), Protein: 13.0g (5 pts), FVN: 0% (0 pts) -> P = 10
    # Raw S = 5 - 10 = -5. Base_Score = round(100 - ((-5 + 15) * 100 / 55)) = 82
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


def test_beverage_strict_sugar_penalty():
    # Cola drink with 10.6g sugar per 100ml:
    # In beverages, sugar is penalized 1 pt per 1.5g -> 10.6 / 1.5 = 7 pts
    # vs solid food where 10.6g is only 2 pts
    bev_nutrition = {
        "energy_kj": 180.0,
        "total_sugars_g": 10.6,
        "sat_fat_g": 0.0,
        "sodium_mg": 10.0,
        "fiber_g": 0.0,
        "protein_g": 0.0,
        "fruit_veg_nut_pct": 0.0,
    }
    bev_score = compute_base_nutriscore(bev_nutrition, is_beverage=True)
    solid_score = compute_base_nutriscore(bev_nutrition, is_beverage=False)
    assert bev_score < solid_score


def test_protein_exclusion_rule_when_n_ge_11():
    # Product with high calories & high sugar giving N >= 11
    # Protein should not be counted if FVN < 80%
    nutrition = {
        "energy_kj": 2400.0,  # 7 pts
        "total_sugars_g": 25.0,  # 5 pts
        "sat_fat_g": 3.0,  # 2 pts
        "sodium_mg": 200.0,  # 2 pts -> N = 16 >= 11
        "fiber_g": 1.0,  # 1 pt
        "protein_g": 12.0,  # 5 pts, but should be EXCLUDED
        "fruit_veg_nut_pct": 10.0,  # 0 pts (< 80%)
    }
    # With protein excluded: P = 1. Raw S = 16 - 1 = 15.
    # Score = round(100 - ((15 + 15) * 100 / 55)) = round(100 - 54.55) = 45.
    # If protein were included: P = 6, S = 10, Score = 55.
    score = compute_base_nutriscore(nutrition, is_beverage=False)
    assert score == 45
