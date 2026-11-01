"""Precision safe consumption dosage and body-weight JECFA ADI scaling engine."""

import math
from typing import Any, Dict, List, Optional


SWEETENER_KEYWORDS = {
    "sugar", "glucose", "sucrose", "dextrose", "syrup", "maltodextrin",
    "honey", "jaggery", "fructose", "invert sugar", "caramel", "molasses",
}

SAT_FAT_KEYWORDS = {
    "palm", "palmolein", "hydrogenated", "vanaspati", "butter",
    "shortening", "ghee", "coconut oil", "lard", "tallow",
}


def normalize_and_impute_nutrition(
    raw_nutrition: Dict[str, Any],
    ingredients_ordered: Optional[List[str]] = None,
    category: Optional[str] = None,
    is_beverage: bool = False,
) -> Dict[str, Any]:
    """Normalize raw label nutrition values and apply heuristics for unreadable metrics."""
    ingredients = ingredients_ordered or []
    top_3_ingredients = [ing.lower() for ing in ingredients[:3]]
    is_estimated = False

    # 1. Salt to Sodium Normalization: Sodium (mg) = Salt (g) * 400
    salt_val = raw_nutrition.get("salt_g")
    sodium_val = raw_nutrition.get("sodium_mg")
    if sodium_val is None and raw_nutrition.get("sodium_mg_per_100g") is not None:
        sodium_val = raw_nutrition.get("sodium_mg_per_100g")

    if (sodium_val is None) and (salt_val is not None):
        sodium_mg = float(salt_val) * 400.0
    else:
        sodium_mg = float(sodium_val or 0.0)

    # 2. Sugar Imputation
    sugar_val = raw_nutrition.get("sugar_g_per_100g")
    if sugar_val is None:
        sugar_val = raw_nutrition.get("total_sugars_g")

    if sugar_val is None:
        has_sweetener_in_top_3 = any(
            any(kw in ing for kw in SWEETENER_KEYWORDS) for ing in top_3_ingredients
        )
        if has_sweetener_in_top_3:
            sugar_g = 22.0
            is_estimated = True
        else:
            sugar_g = 0.0
    else:
        sugar_g = float(sugar_val)

    # 3. Saturated Fat Imputation
    sat_fat_val = raw_nutrition.get("sat_fat_g_per_100g")
    if sat_fat_val is None:
        sat_fat_val = raw_nutrition.get("sat_fat_g")

    if sat_fat_val is None:
        has_sat_fat_in_top_3 = any(
            any(kw in ing for kw in SAT_FAT_KEYWORDS) for ing in top_3_ingredients
        )
        if has_sat_fat_in_top_3:
            sat_fat_g = 12.0
            is_estimated = True
        else:
            sat_fat_g = 0.0
    else:
        sat_fat_g = float(sat_fat_val)

    # 4. Optional Nutrients safe defaults
    energy_kj = float(raw_nutrition.get("energy_kj") or 0.0)
    fiber_g = float(raw_nutrition.get("fiber_g") or 0.0)
    protein_g = float(raw_nutrition.get("protein_g") or 0.0)
    fruit_veg_nut_pct = float(raw_nutrition.get("fruit_veg_nut_pct") or 0.0)
    trans_fat_g = float(raw_nutrition.get("trans_fat_g") or 0.0)

    estimate_badge: Optional[str] = None
    if is_estimated:
        estimate_badge = "Estimated from Ingredient Order — Scan Nutrition Table for Exact Gram Ceiling"

    return {
        "energy_kj": energy_kj,
        "total_sugars_g": sugar_g,
        "sugar_g_per_100g": sugar_g,
        "sat_fat_g": sat_fat_g,
        "sat_fat_g_per_100g": sat_fat_g,
        "sodium_mg": sodium_mg,
        "sodium_mg_per_100g": sodium_mg,
        "fiber_g": fiber_g,
        "protein_g": protein_g,
        "fruit_veg_nut_pct": fruit_veg_nut_pct,
        "trans_fat_g": trans_fat_g,
        "is_estimated": is_estimated,
        "estimate_badge": estimate_badge,
        "is_beverage": is_beverage,
    }


def calculate_prescribed_dosage(
    nutrition: Dict[str, float],
    additives: List[Dict[str, Any]],
    user_weight_kg: float = 65.0,
    is_child: bool = False,
    unit_piece_weight_g: Optional[float] = None,
    product_score: Optional[int] = None,
    nova_grade: Optional[int] = None,
) -> Dict[str, Any]:
    """Calculate safe consumption portion (grams & pieces) and frequency schedule."""
    # 1. 20% WHO Single-Snack Macro Ceilings
    sugar_100g = float(nutrition.get("sugar_g_per_100g") or nutrition.get("total_sugars_g") or 0.0)
    sat_fat_100g = float(nutrition.get("sat_fat_g_per_100g") or nutrition.get("sat_fat_g") or 0.0)
    sodium_100g = float(nutrition.get("sodium_mg_per_100g") or nutrition.get("sodium_mg") or 0.0)

    sugar_per_g = max(sugar_100g / 100.0, 0.0001)
    sat_fat_per_g = max(sat_fat_100g / 100.0, 0.0001)
    sodium_per_g = max(sodium_100g / 100.0, 0.0001)

    portion_sugar = 5.0 / sugar_per_g
    portion_sat_fat = 4.0 / sat_fat_per_g
    portion_sodium = 400.0 / sodium_per_g

    macro_limits = [
        ("Sugar", portion_sugar),
        ("Saturated Fat", portion_sat_fat),
        ("Sodium", portion_sodium),
    ]
    limiting_factor, base_macro_portion = min(macro_limits, key=lambda x: x[1])

    # 2. Body-Weight Scaling (65 kg baseline)
    weight_ratio = max(user_weight_kg, 1.0) / 65.0
    scaled_portion = base_macro_portion * weight_ratio

    # 3. Additive JECFA ADI Constraint
    adi_portion_min = float("inf")
    adi_limiting_additive = None

    for a in additives:
        adi = a.get("jecfa_adi_mg_kg")
        if adi is not None and float(adi) > 0.0:
            conc = float(a.get("default_conc_mg_per_g") or 0.1)
            conc = max(conc, 0.0001)
            # 50% of daily ADI allocated to single snack
            a_portion = (float(adi) * user_weight_kg * 0.50) / conc
            if a_portion < adi_portion_min:
                adi_portion_min = a_portion
                adi_limiting_additive = a.get("primary_name", a.get("ins_code"))

    final_unclamped_portion = scaled_portion
    if adi_portion_min < scaled_portion:
        final_unclamped_portion = adi_portion_min
        limiting_factor = f"Additive ADI ({adi_limiting_additive})"

    # Clamp single-snack portion to max 150g
    clamped_portion = min(final_unclamped_portion, 150.0)
    safe_portion_grams = round(clamped_portion)

    # 4. Safe Pieces Calculation
    safe_pieces: Optional[int] = None
    if unit_piece_weight_g is not None and unit_piece_weight_g > 0:
        safe_pieces = int(math.floor(clamped_portion / unit_piece_weight_g))

    # 5. 4-Tier Frequency Schedule & Child Hyperactivity Override
    has_red_additive = any(
        a.get("risk_tier") == "RED" or int(a.get("triggers_red_cap") or 0) == 1
        for a in additives
    )
    trans_fat = float(nutrition.get("trans_fat_g") or 0.0)

    child_hyperactive_additives = [
        a for a in additives if int(a.get("child_hyperactivity_flag") or 0) == 1
    ]

    frequency_schedule = "Daily Safe"
    frequency_warning: Optional[str] = None

    if is_child and len(child_hyperactive_additives) > 0:
        codes = [f"INS {a.get('ins_code', '')}" for a in child_hyperactive_additives]
        code_str = ", ".join(codes)
        frequency_schedule = "Complete Avoidance Recommended for Children"
        frequency_warning = (
            f"Contains Synthetic Azo Dye {code_str} (Known to cause hyperactivity "
            f"and attention deficit in children per Southampton & EFSA)"
        )
    elif has_red_additive or trans_fat > 0.2:
        frequency_schedule = "Once a Month / Rare Treat"
        if has_red_additive:
            frequency_warning = "Contains Red-Tier toxic additives; frequent consumption carries chronic toxicity risks."
        else:
            frequency_warning = "High trans fat density exceeds WHO threshold."
    elif (product_score is not None and product_score < 50) or (nova_grade == 4) or (sugar_100g > 15.0 or sat_fat_100g > 5.0):
        frequency_schedule = "Strict 1–2x Per Week Cap"
    elif (product_score is not None and product_score < 75) or (nova_grade == 3):
        frequency_schedule = "3–4x Per Week"
    else:
        frequency_schedule = "Daily Safe"

    return {
        "safe_portion_grams": safe_portion_grams,
        "safe_pieces": safe_pieces,
        "limiting_factor": limiting_factor,
        "frequency_schedule": frequency_schedule,
        "frequency_warning": frequency_warning,
        "base_macro_portion": round(base_macro_portion, 2),
        "user_weight_kg": user_weight_kg,
    }
