# testing/unit/phase2/test_ocr_normalizer_and_matcher.py
from pathlib import Path
import sqlite3
import pytest

def test_ocr_normalizer_and_fallbacks():
    workspace = Path(__file__).resolve().parents[3]
    db_path = workspace / "testing" / "scratch" / "test_matcher.db"
    if db_path.exists():
        db_path.unlink()
        
    from data_pipeline.build_master_db import build_database
    build_database(db_path)
    
    from data_pipeline.matcher import match_additive_from_token
    conn = sqlite3.connect(str(db_path))
    
    # Primary: Exact INS regex match
    res = match_additive_from_token("INS 211", conn)
    assert res is not None, "Failed exact INS 211 match"
    assert res["ins_code"] == "211"
    assert res["primary_name"] == "Sodium Benzoate"
    
    # Fallback 1: OCR character corruption (1NS 1O2 -> 102)
    res = match_additive_from_token("1NS 1O2", conn)
    assert res is not None, "Failed OCR char substitution for 1NS 1O2"
    assert res["ins_code"] == "102"
    assert res["primary_name"] == "Tartrazine"
    
    # Fallback 1 variant: Spaced out INS (I N S I02 -> 102)
    res = match_additive_from_token("I N S I02", conn)
    assert res is not None, "Failed OCR char substitution for I N S I02"
    assert res["ins_code"] == "102"
    
    # Fallback 2: Misspelled name via FTS5 trigram (Sodlum Benzoafe -> Sodium Benzoate)
    res = match_additive_from_token("Sodlum Benzoafe", conn)
    assert res is not None, "Failed FTS5 trigram match for Sodlum Benzoafe"
    assert res["ins_code"] == "211"
    
    # Fallback 3: Functional class prefix fallback without code
    res = match_additive_from_token("Contains Permitted Synthetic Food Colour", conn)
    assert res is not None, "Failed functional class prefix fallback"
    assert res["risk_tier"] in ("CAUTION", "RED")
    assert res["is_unspecified_declaration"] is True
    assert "Unspecified Synthetic Additive Declaration" in res["warning_message"]
    
    conn.close()
    if db_path.exists():
        db_path.unlink()

