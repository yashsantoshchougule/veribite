"""On-device and backend OCR text parser for nutrition tables, ingredients, and specular glare detection."""

import re
from typing import Any, Dict, List, Optional


def parse_ocr_nutrition_table(text: str) -> Dict[str, Optional[float]]:
    """Extract standard nutrition parameters from raw OCR text."""
    result: Dict[str, Optional[float]] = {
        "energy_kj": None,
        "total_sugars_g": None,
        "sat_fat_g": None,
        "trans_fat_g": None,
        "sodium_mg": None,
        "salt_g": None,
        "fiber_g": None,
        "protein_g": None,
    }

    # Energy: kcal or kJ
    energy_match = re.search(r"(?:energy|calories?)\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(kcal|kj)?", text, re.I)
    if energy_match:
        val = float(energy_match.group(1))
        unit = (energy_match.group(2) or "").lower()
        if unit == "kj":
            result["energy_kj"] = val
        else:
            result["energy_kj"] = val * 4.184

    # Total Sugars
    sugar_match = re.search(r"(?:total\s+)?sugars?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?", text, re.I)
    if sugar_match:
        result["total_sugars_g"] = float(sugar_match.group(1))

    # Saturated Fat
    sat_fat_match = re.search(r"saturated\s+fat(?:ty\s+acids?)?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?", text, re.I)
    if sat_fat_match:
        result["sat_fat_g"] = float(sat_fat_match.group(1))

    # Trans Fat
    trans_fat_match = re.search(r"trans\s+fat(?:ty\s+acids?)?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?", text, re.I)
    if trans_fat_match:
        result["trans_fat_g"] = float(trans_fat_match.group(1))

    # Sodium
    sodium_match = re.search(r"sodium\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(mg|g)?", text, re.I)
    if sodium_match:
        val = float(sodium_match.group(1))
        unit = (sodium_match.group(2) or "mg").lower()
        result["sodium_mg"] = val * 1000.0 if unit == "g" else val

    # Salt
    salt_match = re.search(r"salt\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?", text, re.I)
    if salt_match:
        result["salt_g"] = float(salt_match.group(1))

    # Fiber
    fiber_match = re.search(r"(?:dietary\s+)?fib(?:er|re)\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?", text, re.I)
    if fiber_match:
        result["fiber_g"] = float(fiber_match.group(1))

    # Protein
    protein_match = re.search(r"protein\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?", text, re.I)
    if protein_match:
        result["protein_g"] = float(protein_match.group(1))

    return result


def parse_ocr_ingredients_and_ins(text: str) -> Dict[str, Any]:
    """Parse comma-separated ingredients and extract parenthetical/bracketed INS codes."""
    ing_header_match = re.search(r"(?:ingredients?|contains?)\s*:\s*(.+)", text, re.I | re.DOTALL)
    body = ing_header_match.group(1) if ing_header_match else text

    # Truncate at end of ingredient section if standard trailing notices exist
    stop_match = re.search(r"(?:allergen|manufactured\s+by|mfg|fssai|net\s+wt|mrp)", body, re.I)
    if stop_match:
        body = body[: stop_match.start()]

    # Split ingredients on commas outside parentheses/brackets
    raw_tokens = re.split(r",(?![^(\[]*[)\]])", body)
    cleaned_tokens = [tok.strip().strip(".") for tok in raw_tokens if tok.strip()]

    # Extract all INS / E-codes
    ins_matches = re.findall(r"(?:ins|e)[-\s]?(\d{3,4}(?:\([a-z0-9iv]+\))?)", body, re.I)
    unique_ins = list(dict.fromkeys(ins_matches))

    return {
        "ingredients": cleaned_tokens,
        "ins_codes": unique_ins,
        "raw_text": body.strip(),
    }


def detect_specular_glare(luminance_pixels: List[int]) -> Dict[str, Any]:
    """Detect specular reflection/foil glare in camera ROI (threshold: > 18% pixels at L > 248)."""
    if not luminance_pixels:
        return {"is_glare": False, "saturated_pct": 0.0, "badge": None}

    total = len(luminance_pixels)
    saturated_count = sum(1 for val in luminance_pixels if val > 248)
    saturated_pct = (saturated_count * 100.0) / total

    is_glare = saturated_pct > 18.0
    badge = "Foil Glare Detected — Tilt Packet 15°" if is_glare else None

    return {
        "is_glare": is_glare,
        "saturated_pct": round(saturated_pct, 2),
        "badge": badge,
    }

