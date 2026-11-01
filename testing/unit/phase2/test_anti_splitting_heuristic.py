# testing/unit/phase2/test_anti_splitting_heuristic.py
from pathlib import Path
import sqlite3
import pytest

def test_anti_splitting_detector_clusters_and_alerts():
    workspace = Path(__file__).resolve().parents[3]
    db_path = workspace / "testing" / "scratch" / "test_splitting.db"
    if db_path.exists():
        db_path.unlink()
        
    from data_pipeline.build_master_db import build_database
    build_database(db_path)
    
    from data_pipeline.matcher import detect_sweetener_cluster
    conn = sqlite3.connect(str(db_path))
    
    # Real-world Indian biscuit label with split sugars:
    # #1: Refined Wheat Flour (Maida)
    # #2: Sugar
    # #3: Palm Oil
    # #4: Liquid Glucose
    # #5: Invert Sugar Syrup
    # #6: Maltodextrin
    raw_ingredients = [
        "Refined Wheat Flour",
        "Sugar",
        "Palm Oil",
        "Liquid Glucose",
        "Invert Sugar Syrup",
        "Maltodextrin",
        "Raising Agents (INS 503ii, INS 500ii)",
        "Iodised Salt",
    ]
    
    result = detect_sweetener_cluster(
        ingredients_ordered=raw_ingredients,
        total_sugars_g=38.0,
        carbohydrates_g=68.0,
        conn=conn
    )
    
    assert result["cluster_detected"] is True
    # Aliases found: Sugar, Liquid Glucose, Invert Sugar Syrup, Maltodextrin
    detected_names = [a["canonical_name"] for a in result["detected_aliases"]]
    assert "Sugar" in detected_names
    assert "Liquid Glucose" in detected_names
    assert "Invert Sugar Syrup" in detected_names
    assert "Maltodextrin" in detected_names
    assert len(detected_names) == 4
    
    # Combined estimated sweetener percentage should be ~38% (anchored to total_sugars_g)
    assert result["combined_estimated_percentage"] >= 35.0
    assert result["exceeds_first_ingredient"] is True
    assert "Hidden Sweetener Alert" in result["alert_message"]
    
    conn.close()
    if db_path.exists():
        db_path.unlink()
