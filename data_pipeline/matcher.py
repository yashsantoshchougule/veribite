"""Multi-tier deterministic additive matcher and OCR corruption normalizer.
Adheres to Ponytail protocol: stdlib only (re, sqlite3, difflib), < 100 lines per focused unit.
"""

import re
import sqlite3
import difflib
from typing import Optional, Dict, Any

def normalize_ocr_additive_token(token: str) -> str:
    """Applies OCR optical character substitution normalization inside additive codes.
    Converts O -> 0, I/l -> 1, S -> 5, B -> 8 for numeric sequences.
    """
    # Normalize spaced tokens e.g. "I N S" -> "INS"
    cleaned = re.sub(r"\bI\s+N\s+S\b", "INS", token, flags=re.IGNORECASE)
    cleaned = re.sub(r"\b1\s*N\s*S\b", "INS", cleaned, flags=re.IGNORECASE)
    
    # Target code patterns like INS 1O2, E-1O2, (1O2)
    def fix_digits(match):
        prefix = match.group(1)
        code = match.group(2)
        trans = str.maketrans({"O": "0", "o": "0", "I": "1", "l": "1", "i": "1", "S": "5", "s": "5", "B": "8"})
        return f"{prefix}{code.translate(trans)}"

    cleaned = re.sub(r"(INS\s*|E-?|\()([0-9OoilSsBb]{3,5}[a-zA-Z]*)", fix_digits, cleaned, flags=re.IGNORECASE)
    return cleaned.strip()

def extract_code_from_token(token: str) -> Optional[str]:
    """Extracts normalized INS code digits from a string."""
    norm = normalize_ocr_additive_token(token)
    match = re.search(r"(?:INS|E)?[ -]?\(?(\d{3,4}[a-z]?(?:\([i-v]+\))?)\)?", norm, re.IGNORECASE)
    if match:
        return match.group(1).lower().replace("(", "").replace(")", "").strip()
    return None

def row_to_dict(row: tuple, cursor: sqlite3.Cursor) -> Dict[str, Any]:
    cols = [col[0] for col in cursor.description]
    return dict(zip(cols, row))

def match_additive_from_token(token: str, conn: sqlite3.Connection) -> Optional[Dict[str, Any]]:
    """Resolves an ingredient token via Primary Regex -> Fallback 1 OCR Sub -> Fallback 2 FTS5 -> Fallback 3 Prefix."""
    if not token or not token.strip():
        return None
    
    cursor = conn.cursor()
    token_clean = token.strip()
    
    # Primary & Fallback 1: Exact / Normalized INS Code Regex Lookup
    code = extract_code_from_token(token_clean)
    if code:
        cursor.execute("SELECT * FROM additives_master WHERE ins_code = ? OR e_code = ?;", (code, f"E{code}"))
        row = cursor.fetchone()
        if row:
            res = row_to_dict(row, cursor)
            res["is_unspecified_declaration"] = False
            return res
        parent_code = re.sub(r"[a-z]+|\([i-v]+\)", "", code)
        if parent_code != code:
            cursor.execute("SELECT * FROM additives_master WHERE ins_code = ?;", (parent_code,))
            row = cursor.fetchone()
            if row:
                res = row_to_dict(row, cursor)
                res["is_unspecified_declaration"] = False
                return res

    # Fallback 2: FTS5 Trigram Substring Matching + Levenshtein / difflib
    words = [w for w in re.split(r"[^\w]+", token_clean) if len(w) >= 3 and not w.isdigit()]
    if words:
        trigrams = []
        for w in words:
            for i in range(len(w) - 2):
                trigrams.append(f'"{w[i:i+3]}"')
        if trigrams:
            fts_query = " OR ".join(trigrams[:8])
            try:
                cursor.execute("SELECT ins_code, primary_name FROM additives_fts WHERE additives_fts MATCH ? LIMIT 15;", (fts_query,))
                candidates = cursor.fetchall()
                best_match = None
                best_ratio = 0.0
                for cand_code, cand_name in candidates:
                    ratio = difflib.SequenceMatcher(None, token_clean.lower(), cand_name.lower()).ratio()
                    if ratio > best_ratio and ratio >= 0.70:
                        best_ratio = ratio
                        best_match = cand_code
                if best_match:
                    cursor.execute("SELECT * FROM additives_master WHERE ins_code = ?;", (best_match,))
                    row = cursor.fetchone()
                    if row:
                        res = row_to_dict(row, cursor)
                        res["is_unspecified_declaration"] = False
                        return res
            except sqlite3.OperationalError:
                pass

    # Fallback 3: Functional Class Prefix Fallback
    lower_token = token_clean.lower()
    if "permitted synthetic" in lower_token or "synthetic food colour" in lower_token:
        return {
            "ins_code": "UNSPECIFIED_SYNTHETIC_COLOUR",
            "e_code": None,
            "primary_name": token_clean,
            "functional_class": "Colour",
            "risk_tier": "RED",
            "triggers_red_cap": 1,
            "jecfa_adi_mg_kg": None,
            "default_conc_mg_per_g": 0.1,
            "child_hyperactivity_flag": 1,
            "banned_jurisdictions": None,
            "citation_id": "EFSA_SOUTHAMPTON_2008",
            "is_unspecified_declaration": True,
            "warning_message": "Unspecified Synthetic Additive Declaration: Contains synthetic colours without declared INS code."
        }
    elif "nature-identical flavour" in lower_token or "artificial flavour" in lower_token or "added flavour" in lower_token:
        return {
            "ins_code": "UNSPECIFIED_FLAVOUR",
            "e_code": None,
            "primary_name": token_clean,
            "functional_class": "Flavouring",
            "risk_tier": "CAUTION",
            "triggers_red_cap": 0,
            "jecfa_adi_mg_kg": None,
            "default_conc_mg_per_g": 0.5,
            "child_hyperactivity_flag": 0,
            "banned_jurisdictions": None,
            "citation_id": "FSSAI_LABELLING_2020",
            "is_unspecified_declaration": True,
            "warning_message": "Unspecified Synthetic Additive Declaration: Contains generic flavouring substances."
        }

    return None
