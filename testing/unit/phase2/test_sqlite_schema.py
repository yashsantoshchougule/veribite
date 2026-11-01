# testing/unit/phase2/test_sqlite_schema.py
import sqlite3
from pathlib import Path
import pytest

def test_database_schema_and_fts5_trigram_structure():
    workspace = Path(__file__).resolve().parents[3]
    db_path = workspace / "testing" / "scratch" / "test_toxicology.db"
    if db_path.exists():
        db_path.unlink()
        
    from data_pipeline.build_master_db import init_database
    conn = init_database(db_path)
    cursor = conn.cursor()
    
    # 1. Verify additives_master table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='additives_master';")
    assert cursor.fetchone() is not None
    
    # 2. Verify FTS5 virtual table exists with trigram tokenizer
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='additives_fts';")
    assert cursor.fetchone() is not None
    
    # 3. Verify check constraints and default values
    cursor.execute("""
        INSERT INTO additives_master (ins_code, e_code, primary_name, functional_class, risk_tier, triggers_red_cap)
        VALUES ('102', 'E102', 'Tartrazine', 'Colour', 'RED', 1);
    """)
    conn.commit()
    
    # 4. Verify FTS5 query works
    cursor.execute("SELECT primary_name FROM additives_fts WHERE additives_fts MATCH 'Tartra*';")
    row = cursor.fetchone()
    assert row is not None and row[0] == "Tartrazine"
    
    conn.close()
    if db_path.exists():
        db_path.unlink()
