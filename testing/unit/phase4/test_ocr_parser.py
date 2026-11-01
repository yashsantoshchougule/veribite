"""Unit tests for Tier 2 OCR text parser and specular glare luminance detector."""

import pytest
from backend.core.ocr_parser import (
    parse_ocr_nutrition_table,
    parse_ocr_ingredients_and_ins,
    detect_specular_glare,
)


def test_parse_ocr_nutrition_table():
    raw_ocr_text = """
    NUTRITIONAL INFORMATION Per 100g:
    Energy: 480 kcal
    Protein: 6.5 g
    Carbohydrate: 68.0 g
    Total Sugars: 32.0 g
    Added Sugars: 28.0 g
    Total Fat: 20.0 g
    Saturated Fatty Acids: 14.0 g
    Trans Fatty Acids: 0.1 g
    Sodium: 220 mg
    Dietary Fiber: 2.5 g
    """
    parsed = parse_ocr_nutrition_table(raw_ocr_text)
    assert parsed["energy_kj"] == pytest.approx(480 * 4.184, rel=1e-2)
    assert parsed["total_sugars_g"] == 32.0
    assert parsed["sat_fat_g"] == 14.0
    assert parsed["trans_fat_g"] == 0.1
    assert parsed["sodium_mg"] == 220.0
    assert parsed["fiber_g"] == 2.5
    assert parsed["protein_g"] == 6.5


def test_parse_ocr_ingredients_and_ins_extraction():
    raw_ocr_text = """
    INGREDIENTS: REFINED WHEAT FLOUR (MAIDA), SUGAR, REFINED PALM OIL,
    INVERT SUGAR SYRUP, FOOD COLOUR (INS 110), RAISING AGENTS [INS 503(ii), INS 500(ii)],
    EMULSIFIER (INS 322), IODISED SALT.
    CONTAINS ADDED FLAVOURS.
    """
    parsed = parse_ocr_ingredients_and_ins(raw_ocr_text)
    ingredients = parsed["ingredients"]
    ins_codes = parsed["ins_codes"]

    assert len(ingredients) >= 6
    assert "REFINED WHEAT FLOUR" in ingredients[0]
    assert "110" in ins_codes
    assert "503(ii)" in ins_codes or "503" in ins_codes
    assert "500(ii)" in ins_codes or "500" in ins_codes
    assert "322" in ins_codes


def test_specular_glare_detector_triggers_above_18_percent():
    # 100 pixels, 25 saturated pixels (L > 248) -> 25% > 18%
    pixels = [255] * 25 + [120] * 75
    glare = detect_specular_glare(pixels)
    assert glare["is_glare"] is True
    assert "Foil Glare Detected" in glare["badge"]
    assert glare["saturated_pct"] == 25.0

    # 100 pixels, 5 saturated pixels (L > 248) -> 5% <= 18%
    clean_pixels = [250] * 5 + [100] * 95
    no_glare = detect_specular_glare(clean_pixels)
    assert no_glare["is_glare"] is False
    assert no_glare["badge"] is None

