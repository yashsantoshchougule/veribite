"""Compiles production SQLite database and bundles it to mobile_app assets."""

import shutil
from pathlib import Path
from data_pipeline.build_master_db import build_database

def compile_and_bundle():
    root = Path(__file__).resolve().parents[1]
    db_path = root / "data_pipeline" / "toxicology_master.db"
    
    # Remove existing if any
    if db_path.exists():
        db_path.unlink()
        
    build_database(db_path)
    
    # Bundle into mobile app assets
    target_path = root / "mobile_app" / "assets" / "db" / "toxicology_master.db"
    target_path.parent.mkdir(parents=True, exist_ok=True)
    if target_path.exists():
        target_path.unlink()
        
    shutil.copy2(db_path, target_path)
    print(f"Compiled and bundled master database:")
    print(f"  Source: {db_path} ({db_path.stat().st_size} bytes)")
    print(f"  Target: {target_path} ({target_path.stat().st_size} bytes)")

if __name__ == "__main__":
    compile_and_bundle()
