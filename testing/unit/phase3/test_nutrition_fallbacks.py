"""Unit tests for missing nutrition imputation and salt normalization fallback engine."""

import pytest
from backend.core.dosage_engine import normalize_and_impute_nutrition


def test_salt_to_sodium_normalization():
    # Sodium is missing, but Salt = 1.5g is declared
    raw_nutrition = {"salt_g": 1.5, "sodium_mg": None}
    norm = normalize_and_impute_nutrition(
        raw_nutrition=raw_nutrition,
        ingredients_ordered=[],
        category="Namkeen",
    )
    assert norm["sodium_mg"] == 600.0  # 1.5 * 400
    assert norm["is_estimated"] is False


def test_ingredient_position_heuristic_imputation():
    # Saturated fat and sugar are unreadable, but ingredients show:
    # 1. Refined Wheat Flour, 2. Sugar, 3. Palm Oil
    raw_nutrition = {
        "sugar_g_per_100g": None,
        "sat_fat_g_per_100g": None,
        "sodium_mg_per_100g": 100.0,
    }
    ingredients = ["Refined Wheat Flour", "Sugar", "Palm Oil", "Salt"]
    norm = normalize_and_impute_nutrition(
        raw_nutrition=raw_nutrition,
        ingredients_ordered=ingredients,
        category="Biscuits",
    )

    assert norm["sugar_g_per_100g"] >= 22.0
    assert norm["sat_fat_g_per_100g"] >= 12.0
    assert norm["is_estimated"] is True
    assert "Estimated from Ingredient Order" in norm["estimate_badge"]


def test_safe_none_handling_and_beverage_density():
    # Completely empty or None-filled dictionary
    raw_nutrition = {
        "energy_kj": None,
        "total_sugars_g": None,
        "sat_fat_g": None,
        "sodium_mg": None,
        "fiber_g": None,
        "protein_g": None,
    }
    norm = normalize_and_impute_nutrition(
        raw_nutrition=raw_nutrition,
        ingredients_ordered=[],
        category="Juice",
        is_beverage=True,
    )
    assert norm["energy_kj"] == 0.0
    assert norm["total_sugars_g"] == 0.0
    assert norm["sat_fat_g"] == 0.0
    assert norm["sodium_mg"] == 0.0
    assert norm["fiber_g"] == 0.0
    assert norm["protein_g"] == 0.0
