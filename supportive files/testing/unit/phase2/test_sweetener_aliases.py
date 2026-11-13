# testing/unit/phase2/test_sweetener_aliases.py
import sqlite3
from pathlib import Path
import pytest

def test_sugar_aliases_complete_60_items_across_5_groups():
    workspace = Path(__file__).resolve().parents[3]
    db_path = workspace / "testing" / "scratch" / "test_tax.db"
    if db_path.exists():
        db_path.unlink()
        
    from data_pipeline.build_master_db import build_database
    build_database(db_path)
    
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # 1. Verify count >= 60
    cursor.execute("SELECT COUNT(*) FROM sugar_aliases;")
    count = cursor.fetchone()[0]
    assert count >= 60, f"Expected at least 60 sugar aliases, found {count}"
    
    # 2. Verify all 5 groups exist
    cursor.execute("SELECT DISTINCT category FROM sugar_aliases;")
    groups = {row[0] for row in cursor.fetchall()}
    assert "Group A" in groups
    assert "Group B" in groups
    assert "Group C" in groups
    assert "Group D" in groups
    assert "Group E" in groups
    
    # 3. Verify specific high-risk Indian aliases
    cursor.execute("SELECT canonical_name FROM sugar_aliases WHERE canonical_name IN ('Liquid Glucose', 'Maltodextrin', 'Invert Sugar Syrup', 'Jaggery (Gur)');")
    names = {row[0] for row in cursor.fetchall()}
    assert "Liquid Glucose" in names
    assert "Maltodextrin" in names
    assert "Invert Sugar Syrup" in names
    assert "Jaggery (Gur)" in names

    # 4. Verify regulatory citations exist
    cursor.execute("SELECT count(*) FROM regulatory_citations;")
    cit_count = cursor.fetchone()[0]
    assert cit_count >= 4, f"Expected citations from WHO, FSSAI, JECFA, EFSA, found {cit_count}"
    
    conn.close()
    if db_path.exists():
        db_path.unlink()

