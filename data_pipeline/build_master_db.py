import sqlite3
from pathlib import Path

def init_database(db_path: Path) -> sqlite3.Connection:
    """Initializes SQLite database with production schema, constraints and FTS5 trigram indexes."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA foreign_keys = ON;")
    
    schema_path = Path(__file__).parent / "schema.sql"
    with open(schema_path, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
        
    return conn
