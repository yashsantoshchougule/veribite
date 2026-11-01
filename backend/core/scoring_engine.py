"""Deterministic Nutri-Score (0-100), NOVA, and 39/100 Red Cap scoring engine."""

from typing import Any, Dict, List, Optional


def _get_points(value: float, thresholds: List[float]) -> int:
    """Return point index based on ascending thresholds."""
    for i, t in enumerate(thresholds):
        if value <= t:
            return i
    return len(thresholds)


def compute_negative_points(nutrition: Dict[str, float], is_beverage: bool = False) -> Dict[str, int]:
    """Compute Nutri-Score negative points (N) 0-40."""
    energy_kj = float(nutrition.get("energy_kj") or 0.0)
    sugars_g = float(nutrition.get("total_sugars_g") or 0.0)
    sat_fat_g = float(nutrition.get("sat_fat_g") or 0.0)
    sodium_mg = float(nutrition.get("sodium_mg") or 0.0)

    if is_beverage:
        e_thresholds = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270]
        s_thresholds = [0.0, 1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0, 13.5]
    else:
        e_thresholds = [335, 670, 1005, 1340, 1675, 2010, 2345, 2680, 3015, 3350]
        s_thresholds = [4.5, 9.0, 13.5, 18.0, 22.5, 27.0, 31.5, 36.0, 40.5, 45.0]

    fat_thresholds = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    na_thresholds = [90, 180, 270, 360, 450, 540, 630, 720, 810, 900]

    return {
        "energy_pts": _get_points(energy_kj, e_thresholds),
        "sugar_pts": _get_points(sugars_g, s_thresholds),
        "sat_fat_pts": _get_points(sat_fat_g, fat_thresholds),
        "sodium_pts": _get_points(sodium_mg, na_thresholds),
    }


def compute_positive_points(
    nutrition: Dict[str, float],
    negative_points_total: int,
    is_beverage: bool = False,
) -> Dict[str, int]:
    """Compute Nutri-Score positive points (P) 0-15."""
    fvn_pct = float(nutrition.get("fruit_veg_nut_pct") or 0.0)
    fiber_g = float(nutrition.get("fiber_g") or 0.0)
    protein_g = float(nutrition.get("protein_g") or 0.0)

    if is_beverage:
        fvn_pts = 0 if fvn_pct <= 40 else (2 if fvn_pct <= 60 else (4 if fvn_pct <= 80 else 10))
    else:
        fvn_pts = 0 if fvn_pct <= 40 else (1 if fvn_pct <= 60 else (2 if fvn_pct <= 80 else 5))

    fiber_pts = _get_points(fiber_g, [0.9, 1.9, 2.8, 3.7, 4.7])
    raw_protein_pts = _get_points(protein_g, [1.6, 3.2, 4.8, 6.4, 8.0])

    # Rule: If N >= 11 and FVN < 80%, protein points are excluded
    protein_pts = raw_protein_pts if (negative_points_total < 11 or fvn_pct >= 80.0) else 0

    return {
        "fvn_pts": fvn_pts,
        "fiber_pts": fiber_pts,
        "protein_pts": protein_pts,
    }


def compute_base_nutriscore(nutrition: Dict[str, float], is_beverage: bool = False) -> int:
    """Calculate baseline Nutri-Score mapped to 0-100 scale (higher = healthier)."""
    n_pts_dict = compute_negative_points(nutrition, is_beverage=is_beverage)
    n_total = sum(n_pts_dict.values())

    p_pts_dict = compute_positive_points(nutrition, n_total, is_beverage=is_beverage)
    p_total = sum(p_pts_dict.values())

    raw_s = n_total - p_total
    # Map raw_s (-15 to +40) to 0-100
    score = round(100.0 - ((raw_s + 15.0) * 100.0 / 55.0))
    return max(0, min(100, score))
