"""Barcode validation, normalization, and GS1 Digital Link resolver."""

import re
from typing import Optional


def calculate_ean13_check_digit(digits_12: str) -> int:
    """Compute EAN-13 check digit from first 12 digits."""
    s = 0
    for idx, char in enumerate(digits_12):
        weight = 1 if idx % 2 == 0 else 3
        s += int(char) * weight
    return (10 - (s % 10)) % 10


def calculate_ean8_check_digit(digits_7: str) -> int:
    """Compute EAN-8 check digit from first 7 digits."""
    s = 0
    for idx, char in enumerate(digits_7):
        weight = 3 if idx % 2 == 0 else 1
        s += int(char) * weight
    return (10 - (s % 10)) % 10


def validate_and_normalize_barcode(raw_input: str) -> Optional[str]:
    """Validate, clean, and normalize EAN-13, EAN-8, UPC-A, or GS1 Digital Link."""
    if not raw_input or not isinstance(raw_input, str):
        return None

    cleaned = raw_input.strip()

    # GS1 Digital Link extraction: e.g. https://id.gs1.org/01/08901030383786
    gs1_match = re.search(r"/01/(\d{12,14})", cleaned)
    if gs1_match:
        gtin = gs1_match.group(1)
        if len(gtin) == 14 and gtin.startswith("0"):
            cleaned = gtin[1:]
        else:
            cleaned = gtin

    # Strip any non-digit chars
    digits = re.sub(r"\D", "", cleaned)

    # 1. UPC-A (12 digits) -> convert to 13-digit EAN-13 with leading 0
    if len(digits) == 12:
        digits = "0" + digits

    # 2. EAN-13 (13 digits)
    if len(digits) == 13:
        expected_check = calculate_ean13_check_digit(digits[:12])
        if int(digits[12]) == expected_check:
            return digits
        return None

    # 3. EAN-8 (8 digits)
    if len(digits) == 8:
        expected_check = calculate_ean8_check_digit(digits[:7])
        if int(digits[7]) == expected_check:
            return digits
        return None

    return None

