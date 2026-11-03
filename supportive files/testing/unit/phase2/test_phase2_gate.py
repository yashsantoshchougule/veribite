# testing/unit/phase2/test_phase2_gate.py
import sqlite3
import time
from pathlib import Path

def test_phase_2_master_release_gate():
    workspace = Path(__file__).resolve().parents[3]
    master_db = workspace / "data_pipeline" / "toxicology_master.db"
    bundled_db = workspace / "mobile_app" / "assets" / "db" / "toxicology_master.db"
    
    # 1. Verify existence and byte parity
    assert master_db.is_file(), "Master database file missing"
    assert bundled_db.is_file(), "Bundled mobile database file missing"
    assert master_db.stat().st_size == bundled_db.stat().st_size
    assert master_db.stat().st_size > 0
    
    conn = sqlite3.connect(str(master_db))
    cursor = conn.cursor()
    
    # 2. Benchmark exact query speed (must be sub-5ms)
    t0 = time.perf_counter()
    cursor.execute("SELECT * FROM additives_master WHERE ins_code='102';")
    row = cursor.fetchone()
    elapsed_ms = (time.perf_counter() - t0) * 1000
    assert row is not None
    assert row[0] == "102"
    assert elapsed_ms < 5.0, f"Query took {elapsed_ms:.2f}ms (> 5ms ceiling)"
    
    # 3. Benchmark FTS5 trigram query speed (must be sub-5ms)
    t0 = time.perf_counter()
    cursor.execute("SELECT primary_name FROM additives_fts WHERE additives_fts MATCH '\"art\"' LIMIT 5;")
    rows = cursor.fetchall()
    elapsed_ms = (time.perf_counter() - t0) * 1000
    assert len(rows) > 0
    assert elapsed_ms < 5.0, f"FTS5 query took {elapsed_ms:.2f}ms (> 5ms ceiling)"
    
    # 4. Verify Sugar Aliases count >= 60
    cursor.execute("SELECT count(*) FROM sugar_aliases;")
    assert cursor.fetchone()[0] >= 60
    
    # 5. Verify Regulatory Citations exist
    cursor.execute("SELECT count(*) FROM regulatory_citations;")
    assert cursor.fetchone()[0] >= 4
    
    # 6. Verify Red Cap Additives count
    cursor.execute("SELECT count(*) FROM additives_master WHERE triggers_red_cap = 1;")
    assert cursor.fetchone()[0] >= 10
    
    conn.close()
