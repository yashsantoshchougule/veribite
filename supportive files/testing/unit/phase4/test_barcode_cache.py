"""Unit tests for barcode normalization and local product cache SQLite repository."""

import sqlite3
import pytest
from backend.core.barcode_normalizer import (
    validate_and_normalize_barcode,
    calculate_ean13_check_digit,
)
from backend.core.product_cache import LocalProductCache


def test_ean13_validation_and_normalization():
    # Valid EAN-13 barcode: "8901030383786"
    assert validate_and_normalize_barcode("8901030383786") == "8901030383786"

    # EAN-13 with invalid check digit fails
    assert validate_and_normalize_barcode("8901030383789") is None

    # GS1 Digital Link URL extraction
    url = "https://id.gs1.org/01/08901030383786"
    assert validate_and_normalize_barcode(url) == "8901030383786"


def test_upca_and_ean8_normalization():
    # UPC-A (12 digits, e.g. 012345678905) converted to EAN-13 with leading 0
    assert validate_and_normalize_barcode("012345678905") == "0012345678905"

    # Valid EAN-8: "96385074"
    assert validate_and_normalize_barcode("96385074") == "96385074"


def test_local_product_cache_sqlite_roundtrip(tmp_path):
    db_file = tmp_path / "test_cache.db"
    cache = LocalProductCache(db_path=str(db_file))
    cache.init_table()

    product_data = {
        "barcode": "8901030383786",
        "product_name": "Orange Cream Biscuits",
        "brand_name": "Britannia",
        "category": "Biscuits",
        "serving_size_g": 20.0,
        "piece_weight_g": 10.0,
        "nutrition_json": '{"sugar_g_per_100g": 32.0, "sat_fat_g_per_100g": 14.0}',
        "additives_json": '[{"ins_code": "110", "risk_tier": "RED"}]',
        "health_score": 22,
        "nova_grade": 4,
        "red_cap_triggered": 1,
        "ingredient_hash": "a1b2c3d4e5f6",
    }

    cache.set_product(product_data)

    retrieved = cache.get_product("8901030383786")
    assert retrieved is not None
    assert retrieved["product_name"] == "Orange Cream Biscuits"
    assert retrieved["health_score"] == 22
    assert retrieved["red_cap_triggered"] == 1

