"""Precision safe consumption dosage and body-weight JECFA ADI scaling engine."""

import math
from typing import Any, Dict, List, Optional


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
