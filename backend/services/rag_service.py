"""Citation-grounded RAG context assembler and regulatory citations database client."""

import sqlite3
from typing import Any, Dict, List, Optional


def fetch_citations_for_additives(
    db_path: str = "data_pipeline/toxicology_master.db",
    ins_codes: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    """Query verified regulatory citations from SQLite for detected INS codes."""
    codes = ins_codes or []
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        cursor = conn.cursor()
        if codes:
            placeholders = ",".join("?" for _ in codes)
            query = f"""
                SELECT citation_id, authority, ins_code, verified_passage, source_url
                FROM regulatory_citations
                WHERE ins_code IN ({placeholders}) OR ins_code IS NULL
                ORDER BY authority ASC;
            """
            cursor.execute(query, tuple(codes))
        else:
            cursor.execute("""
                SELECT citation_id, authority, ins_code, verified_passage, source_url
                FROM regulatory_citations
                WHERE ins_code IS NULL
                ORDER BY authority ASC;
            """)
        rows = cursor.fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def build_advisor_rag_context(
    product: Dict[str, Any],
    guardrails: Dict[str, Any],
    citations: List[Dict[str, Any]],
) -> str:
    """Build zero-hallucination prompt context injecting product, user diseases, and citations."""
    product_name = product.get("product_name", "Unknown Product")
    category = product.get("category", "General Food")
    nutrition = product.get("nutrition", {})
    additives = product.get("additives", [])

    user_weight = guardrails.get("weight_kg", 65.0)
    is_child = guardrails.get("is_child", False)
    is_diabetic = guardrails.get("is_diabetic", False)
    is_hypertensive = guardrails.get("is_hypertensive", False)

    citation_lines = []
    for c in citations:
        citation_lines.append(
            f"- [{c['citation_id']}] ({c['authority']}): \"{c['verified_passage']}\""
        )
    citations_text = "\n".join(citation_lines) if citation_lines else "No specific monograph citations."

    additives_text = ", ".join(
        f"{a.get('primary_name', 'INS ' + str(a.get('ins_code')))} ({a.get('risk_tier', 'UNKNOWN')})"
        for a in additives
    ) or "None detected"

    return f"""You are the Personal Food Safety Advisor powering Page 11 of the Packaged Product Scanner.
Answer user questions with strict grounding in the supplied verified regulatory citations and nutritional facts.

ZERO-HALLUCINATION GUARDRAIL:
1. Every medical risk claim, additive toxicity warning, or daily ceiling claim MUST cite the exact [Citation_ID] from the Verified Citations list below.
2. If no official monograph exists for a claim, explicitly state "NO_OFFICIAL_SOURCE". Prohibit speculative medical advice.

PRODUCT CONTEXT:
- Name: {product_name} ({category})
- Sugars: {nutrition.get('total_sugars_g', 0)}g / 100g
- Saturated Fat: {nutrition.get('sat_fat_g', 0)}g / 100g
- Sodium: {nutrition.get('sodium_mg', 0)}mg / 100g
- Detected Additives: {additives_text}

USER HEALTH GUARDRAILS:
- Weight: {user_weight}kg
- Child Profile: {"YES" if is_child else "NO"}
- Diabetic: {"YES" if is_diabetic else "NO"}
- Hypertension: {"YES" if is_hypertensive else "NO"}

VERIFIED REGULATORY CITATIONS:
{citations_text}
"""
