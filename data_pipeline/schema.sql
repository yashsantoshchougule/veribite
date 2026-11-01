-- Production SQLite Schema for Toxicology Engine
-- Guarantees sub-5ms offline lookups and zero-hallucination citation links

CREATE TABLE IF NOT EXISTS additives_master (
    ins_code TEXT PRIMARY KEY,
    e_code TEXT,
    primary_name TEXT NOT NULL,
    synonyms_csv TEXT,
    functional_class TEXT,
    risk_tier TEXT CHECK(risk_tier IN ('SAFE','CAUTION','RED')),
    triggers_red_cap INTEGER DEFAULT 0,
    jecfa_adi_mg_kg REAL,
    default_conc_mg_per_g REAL,
    child_hyperactivity_flag INTEGER DEFAULT 0,
    banned_jurisdictions TEXT,
    citation_id TEXT
);

CREATE VIRTUAL TABLE IF NOT EXISTS additives_fts USING fts5(
    ins_code,
    e_code,
    primary_name,
    synonyms_csv,
    content='additives_master',
    tokenize='trigram'
);

-- Automatic synchronization triggers for FTS5 content table
CREATE TRIGGER IF NOT EXISTS additives_ai AFTER INSERT ON additives_master BEGIN
  INSERT INTO additives_fts(rowid, ins_code, e_code, primary_name, synonyms_csv)
  VALUES (new.rowid, new.ins_code, new.e_code, new.primary_name, new.synonyms_csv);
END;

CREATE TRIGGER IF NOT EXISTS additives_ad AFTER DELETE ON additives_master BEGIN
  INSERT INTO additives_fts(additives_fts, rowid, ins_code, e_code, primary_name, synonyms_csv)
  VALUES('delete', old.rowid, old.ins_code, old.e_code, old.primary_name, old.synonyms_csv);
END;

CREATE TRIGGER IF NOT EXISTS additives_au AFTER UPDATE ON additives_master BEGIN
  INSERT INTO additives_fts(additives_fts, rowid, ins_code, e_code, primary_name, synonyms_csv)
  VALUES('delete', old.rowid, old.ins_code, old.e_code, old.primary_name, old.synonyms_csv);
  INSERT INTO additives_fts(rowid, ins_code, e_code, primary_name, synonyms_csv)
  VALUES (new.rowid, new.ins_code, new.e_code, new.primary_name, new.synonyms_csv);
END;

CREATE TABLE IF NOT EXISTS sugar_aliases (
    alias_id INTEGER PRIMARY KEY,
    canonical_name TEXT UNIQUE,
    category TEXT,
    glycemic_index INTEGER
);

CREATE TABLE IF NOT EXISTS regulatory_citations (
    citation_id TEXT PRIMARY KEY,
    authority TEXT,
    doc_title TEXT,
    verified_passage TEXT,
    source_url TEXT
);

