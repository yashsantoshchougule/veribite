import sqlite3
from pathlib import Path
from data_pipeline.taxonomy_data import SUGAR_ALIASES, REGULATORY_CITATIONS

def init_database(db_path: Path) -> sqlite3.Connection:
    """Initializes SQLite database with production schema, constraints and FTS5 trigram indexes."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA foreign_keys = ON;")
    
    schema_path = Path(__file__).parent / "schema.sql"
    with open(schema_path, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
        
    return conn

def seed_taxonomy_and_citations(conn: sqlite3.Connection):
    """Seeds canonical sugar aliases and verified regulatory citations."""
    cursor = conn.cursor()
    
    # 1. Seed 60 Sweetener Aliases
    for i, alias in enumerate(SUGAR_ALIASES, start=1):
        cursor.execute("""
            INSERT OR REPLACE INTO sugar_aliases (alias_id, canonical_name, category, glycemic_index)
            VALUES (?, ?, ?, ?);
        """, (i, alias["canonical_name"], alias["category"], alias["glycemic_index"]))
        
    # 2. Seed Regulatory Citations
    for cit in REGULATORY_CITATIONS:
        cursor.execute("""
            INSERT OR REPLACE INTO regulatory_citations (citation_id, authority, doc_title, verified_passage, source_url)
            VALUES (?, ?, ?, ?, ?);
        """, (cit["citation_id"], cit["authority"], cit["doc_title"], cit["verified_passage"], cit["source_url"]))
        
    conn.commit()

def build_database(db_path: Path):
    """Builds complete toxicology master database with schema and pre-seeded tables."""
    conn = init_database(db_path)
    seed_taxonomy_and_citations(conn)
    conn.close()
