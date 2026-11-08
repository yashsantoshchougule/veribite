import json
import sqlite3
from pathlib import Path
from data_pipeline.taxonomy_data import SUGAR_ALIASES, REGULATORY_CITATIONS, ADDITIVES_CORPUS

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
        
    # 3. Seed Additives Corpus (Prefer comprehensive 700+ canonical additives if available)
    json_path = Path(__file__).parent / "full_additives_corpus.json"
    if json_path.exists():
        with open(json_path, "r", encoding="utf-8") as f:
            additives_to_seed = json.load(f)
    else:
        additives_to_seed = ADDITIVES_CORPUS

    for item in additives_to_seed:
        cursor.execute("""
            INSERT OR REPLACE INTO additives_master (
                ins_code, e_code, primary_name, synonyms_csv, functional_class,
                risk_tier, triggers_red_cap, jecfa_adi_mg_kg, default_conc_mg_per_g,
                child_hyperactivity_flag, banned_jurisdictions, citation_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            item["ins_code"], item["e_code"], item["primary_name"], item["synonyms_csv"],
            item["functional_class"], item["risk_tier"], item["triggers_red_cap"],
            item["jecfa_adi_mg_kg"], item["default_conc_mg_per_g"],
            item["child_hyperactivity_flag"], item["banned_jurisdictions"], item["citation_id"]
        ))
        
    # 4. Rebuild FTS5 Trigram Index for perfect rowid alignment
    cursor.execute("INSERT INTO additives_fts(additives_fts) VALUES('rebuild');")

    conn.commit()

def build_database(db_path: Path):
    """Builds complete toxicology master database with schema and pre-seeded tables."""
    conn = init_database(db_path)
    seed_taxonomy_and_citations(conn)
    conn.close()
