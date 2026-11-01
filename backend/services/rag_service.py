"""Citation-grounded RAG context assembler and regulatory citations database client."""

import sqlite3
from typing import Any, Dict, List, Optional
from backend.core.dosage_engine import calculate_prescribed_dosage


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


def synthesize_rule_based_advice(
    product: Dict[str, Any],
    guardrails: Dict[str, Any],
    citations: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """Deterministic Rule-Based Regulatory Synthesizer for LLM outage/HTTP 429 fallback."""
    product_name = product.get("product_name", "Packaged Product")
    nutrition = product.get("nutrition", {})
    additives = product.get("additives", [])

    user_weight_kg = float(guardrails.get("weight_kg") or 65.0)
    is_child = bool(guardrails.get("is_child", False))
    is_diabetic = bool(guardrails.get("is_diabetic", False))
    is_hypertensive = bool(guardrails.get("is_hypertensive", False))

    # Calculate exact dosage
    dosage = calculate_prescribed_dosage(
        nutrition=nutrition,
        additives=additives,
        user_weight_kg=user_weight_kg,
        is_child=is_child,
    )

    sugar_100g = float(nutrition.get("sugar_g_per_100g") or nutrition.get("total_sugars_g") or 0.0)
    sodium_100g = float(nutrition.get("sodium_mg_per_100g") or nutrition.get("sodium_mg") or 0.0)

    alerts: List[str] = []

    if is_diabetic and sugar_100g > 5.0:
        alerts.append(f"⚠️ **Diabetic Alert:** High total sugar density ({sugar_100g:.1f}g/100g) exceeds recommended glycemic ceiling for diabetes.")

    if is_hypertensive and sodium_100g > 400.0:
        alerts.append(f"⚠️ **Hypertension Alert:** Sodium density ({sodium_100g:.0f}mg/100g) exceeds 20% WHO single-snack limit for hypertension.")

    has_azo_dye = any(int(a.get("child_hyperactivity_flag") or 0) == 1 for a in additives)
    if is_child and has_azo_dye:
        alerts.append("🚫 **Child Safety Alert:** Contains synthetic azo dye colorants linked to attention deficit and hyperactivity in children per Southampton & EFSA.")

    # Regulatory evidence references
    citation_lines = []
    for c in citations:
        citation_lines.append(f"- **[{c['citation_id']}]** ({c['authority']}): {c['verified_passage']}")
    citations_text = "\n".join(citation_lines) if citation_lines else "- No specific official monographs found."

    alerts_text = "\n".join(alerts) + "\n" if alerts else ""

    advice_text = f"""### Safety Summary for {product_name}

- **Prescribed Safe Portion:** **{dosage['safe_portion_grams']}g** ({dosage['safe_pieces'] or 0} pieces)
- **Consumption Frequency:** **{dosage['frequency_schedule']}**
- **Limiting Factor:** {dosage['limiting_factor']}

{alerts_text}
#### Verified Regulatory Evidence:
{citations_text}

*(Generated by deterministic Rule-Based Safety Synthesizer — Zero-Hallucination Fallback)*"""

    return {
        "source": "rule_based_fallback",
        "product_name": product_name,
        "advice_text": advice_text,
        "safe_portion_grams": dosage["safe_portion_grams"],
        "safe_pieces": dosage["safe_pieces"],
        "frequency_schedule": dosage["frequency_schedule"],
        "citations": [c["citation_id"] for c in citations],
    }
