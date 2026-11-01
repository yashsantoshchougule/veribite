"""Multi-tier deterministic additive matcher, OCR corruption normalizer,
and anti-splitting hidden sweetener cluster detector.
Adheres to Ponytail protocol: stdlib only (re, sqlite3, difflib, math), < 100 lines per focused unit.
"""

import re
import sqlite3
import difflib
import math
from typing import Optional, Dict, Any, List

def normalize_ocr_additive_token(token: str) -> str:
    """Applies OCR optical character substitution normalization inside additive codes.
    Converts O -> 0, I/l -> 1, S -> 5, B -> 8 for numeric sequences.
    """
    cleaned = re.sub(r"\bI\s+N\s+S\b", "INS", token, flags=re.IGNORECASE)
    cleaned = re.sub(r"\b1\s*N\s*S\b", "INS", cleaned, flags=re.IGNORECASE)
    
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

def detect_sweetener_cluster(
    ingredients_ordered: List[str],
    total_sugars_g: float,
    carbohydrates_g: float,
    conn: sqlite3.Connection
) -> Dict[str, Any]:
    """Detects split hidden sweeteners using FSSAI descending order rank decay.
    Aggregates aliases into Total Sweetener Cluster and checks if combined sugar exceeds #1 ingredient.
    """
    cursor = conn.cursor()
    cursor.execute("SELECT canonical_name, category, glycemic_index FROM sugar_aliases;")
    alias_rows = cursor.fetchall()
    
    # Map for case-insensitive lookup
    alias_map = {row[0].lower(): {"canonical_name": row[0], "category": row[1], "glycemic_index": row[2]} for row in alias_rows}
    
    detected_sweeteners = []
    first_ingredient = ingredients_ordered[0] if ingredients_ordered else "Primary Ingredient"
    
    for rank, ing in enumerate(ingredients_ordered):
        clean_ing = ing.lower().strip()
        matched_alias = None
        
        # Check exact or substring containment
        for alias_key, alias_info in alias_map.items():
            # Check pattern boundary
            pattern = r"\b" + re.escape(alias_key.split("(")[0].strip()) + r"\b"
            if re.search(pattern, clean_ing):
                matched_alias = alias_info
                break
                
        if matched_alias:
            detected_sweeteners.append({
                "rank": rank + 1,
                "raw_text": ing,
                "canonical_name": matched_alias["canonical_name"],
                "category": matched_alias["category"],
                "glycemic_index": matched_alias["glycemic_index"]
            })
            
    num_detected = len(detected_sweeteners)
    cluster_detected = num_detected >= 2 or (num_detected >= 1 and total_sugars_g >= 15.0)
    
    # Geometric Rank Decay Estimation: w_i = alpha * exp(-lambda * rank)
    # Total sweetener percentage is anchored by nutrition table's total_sugars_g
    combined_percentage = max(total_sugars_g, 0.0)
    
    # Estimate #1 ingredient percentage:
    # If sweeteners appear at ranks 2, 4, 5, etc., their weights decay.
    # Total product is 100%. The #1 ingredient cannot exceed (100 - sum(sweeteners) - sum(other fats/flour)).
    lambda_decay = 0.25
    decay_weights = [math.exp(-lambda_decay * i) for i in range(len(ingredients_ordered))]
    total_decay = sum(decay_weights)
    
    # Normalized share of #1 ingredient
    w1_share = (decay_weights[0] / total_decay) * (100.0 - combined_percentage)
    
    exceeds_first = combined_percentage > w1_share
    
    alert_message = ""
    if cluster_detected and num_detected >= 2:
        names_str = ", ".join([s["canonical_name"] for s in detected_sweeteners])
        alert_message = (
            f"Hidden Sweetener Alert: Manufacturers split sweeteners into {num_detected} aliases "
            f"({names_str}). Combined sweeteners (~{combined_percentage:.1f}%) "
            f"{'exceed' if exceeds_first else 'rival'} the primary ingredient {first_ingredient}!"
        )
    elif cluster_detected:
        alert_message = f"High Sweetener Concentration: Contains ~{combined_percentage:.1f}% total sugars."
        
    return {
        "cluster_detected": cluster_detected,
        "detected_aliases": detected_sweeteners,
        "combined_estimated_percentage": combined_percentage,
        "first_ingredient_estimated_percentage": round(w1_share, 1),
        "exceeds_first_ingredient": exceeds_first,
        "alert_message": alert_message
    }
