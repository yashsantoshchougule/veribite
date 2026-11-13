# testing/unit/phase2/test_additive_corpus.py
import sqlite3
from pathlib import Path
import pytest

def test_additive_corpus_and_red_cap_triggers():
    workspace = Path(__file__).resolve().parents[3]
    db_path = workspace / "testing" / "scratch" / "test_additives.db"
    if db_path.exists():
        db_path.unlink()
        
    from data_pipeline.build_master_db import build_database
    build_database(db_path)
    
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # 1. Verify Southampton Six Azo Dyes trigger red cap & hyperactivity flag
    cursor.execute("SELECT ins_code, risk_tier, triggers_red_cap, child_hyperactivity_flag, jecfa_adi_mg_kg FROM additives_master WHERE ins_code='102';")
    row = cursor.fetchone()
    assert row is not None
    assert row[1] == "RED"
    assert row[2] == 1
    assert row[3] == 1
    assert row[4] == 7.5  # JECFA ADI mg/kg
    
    # 2. Verify Sunset Yellow FCF (INS 110)
    cursor.execute("SELECT risk_tier, triggers_red_cap, child_hyperactivity_flag, jecfa_adi_mg_kg FROM additives_master WHERE ins_code='110';")
    row = cursor.fetchone()
    assert row == ("RED", 1, 1, 4.0)
    
    # 3. Verify Citric Acid (INS 330) is SAFE with no numeric ADI ceiling
    cursor.execute("SELECT risk_tier, triggers_red_cap, jecfa_adi_mg_kg FROM additives_master WHERE ins_code='330';")
    row = cursor.fetchone()
    assert row is not None
    assert row[0] == "SAFE"
    assert row[1] == 0
    assert row[2] is None  # ADI Not Specified
    
    # 4. Verify FTS5 automatically indexed the newly inserted additives
    cursor.execute("SELECT primary_name FROM additives_fts WHERE additives_fts MATCH 'Sunset';")
    fts_row = cursor.fetchone()
    assert fts_row is not None
    assert "Sunset Yellow" in fts_row[0]

    # 5. Verify total pre-loaded comprehensive additive count >= 600
    cursor.execute("SELECT count(*) FROM additives_master;")
    total_additives = cursor.fetchone()[0]
    assert total_additives >= 600, f"Expected >= 600 additives, found {total_additives}"

    # 6. Verify newly expanded additives
    # INS 476: Polyglycerol polyricinoleate (Emulsifier in chocolates) -> CAUTION
    cursor.execute("SELECT risk_tier, triggers_red_cap, functional_class FROM additives_master WHERE ins_code='476';")
    row_476 = cursor.fetchone()
    assert row_476 is not None
    assert row_476[0] == "CAUTION"
    assert row_476[1] == 0

    # INS 171: Titanium dioxide (Genotoxic / Banned in EU) -> RED with red cap
    cursor.execute("SELECT risk_tier, triggers_red_cap FROM additives_master WHERE ins_code='171';")
    row_171 = cursor.fetchone()
    assert row_171 is not None
    assert row_171[0] == "RED"
    assert row_171[1] == 1

    # INS 220: Sulfur dioxide (Sulfite allergen / Preservative) -> CAUTION
    cursor.execute("SELECT risk_tier FROM additives_master WHERE ins_code='220';")
    row_220 = cursor.fetchone()
    assert row_220 is not None
    assert row_220[0] == "CAUTION"

    # 7. Verify FTS5 trigram search on newly expanded additives
    cursor.execute("SELECT primary_name FROM additives_fts WHERE additives_fts MATCH '476';")
    fts_476 = cursor.fetchone()
    assert fts_476 is not None
    assert "polyricinoleate" in fts_476[0].lower() or "476" in fts_476[0].lower()
    
    conn.close()
    if db_path.exists():
        db_path.unlink()

