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
        cursor.execute("PRAGMA table_info(regulatory_citations);")
        columns = [row["name"] for row in cursor.fetchall()]
        has_ins_code = "ins_code" in columns

        if has_ins_code:
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
        else:
            if codes:
                placeholders = ",".join("?" for _ in codes)
                query = f"""
                    SELECT r.citation_id, r.authority, a.ins_code, r.verified_passage, r.source_url
                    FROM regulatory_citations r
                    JOIN additives_master a ON r.citation_id = a.citation_id
                    WHERE a.ins_code IN ({placeholders})
                    UNION
                    SELECT citation_id, authority, NULL as ins_code, verified_passage, source_url
                    FROM regulatory_citations
                    WHERE citation_id NOT IN (SELECT citation_id FROM additives_master WHERE citation_id IS NOT NULL)
                    ORDER BY authority ASC;
                """
                cursor.execute(query, tuple(codes))
            else:
                cursor.execute("""
                    SELECT citation_id, authority, NULL as ins_code, verified_passage, source_url
                    FROM regulatory_citations
                    WHERE citation_id NOT IN (SELECT citation_id FROM additives_master WHERE citation_id IS NOT NULL)
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

    return f"""You are the VeriBite AI Advisor, an expert in packaged food toxicology, ingredient analysis, and VeriBite app guidance.
Answer user questions with strict grounding in the supplied verified regulatory citations and nutritional facts.

STRICT BEHAVIORAL REGULATIONS & SAFETY BOUNDARIES:
1. IDENTITY RULE: You are ONLY the "VeriBite AI Advisor". NEVER disclose or mention your underlying AI model (e.g., Gemini, GPT, LLM), model version, or creator/developer (e.g., Google, OpenAI, DeepMind). If asked who created you or what model you are, state only that you are the VeriBite AI Advisor built for this app.
2. STRICT DOMAIN BOUNDARY: You answer questions related to packaged foods, ingredients, chemical INS additives, nutrition facts, toxicology, and safe portion limits.
   For ANY question strictly unrelated to food, nutrition, or the VeriBite app, politely refuse.
3. CHARITABLE TYPO INTERPRETATION: Always interpret user typos charitably (e.g., "colestrol" -> cholesterol, "carb/carbohydrate").
4. INTELLIGENT NUTRIENT INFERENCE: If asked about a nutrient not explicitly printed in the label numbers, do not say "Data missing". Provide the scientifically deduced value (e.g., plant formulations like Safi contain 0 mg cholesterol because plants lack cholesterol; carbs come from the invert sugar syrup base).
5. CONCISENESS & BREVITY: Give ONLY the details requested. Keep your response direct, practical, and focused strictly on the user query (under 150 words).
6. ZERO-HALLUCINATION GUARDRAIL:
   - Every medical risk claim, additive toxicity warning, or daily ceiling claim MUST cite the exact [Citation_ID] from the Verified Citations list below.
   - If no official monograph exists for a claim, explicitly state "NO_OFFICIAL_SOURCE". Prohibit speculative medical advice.

PRODUCT CONTEXT:
- Name: {product_name} ({category})
- Calories: {nutrition.get('calories') or nutrition.get('energy_kcal') or 'N/A'} kcal
- Total Carbohydrates: {nutrition.get('carbohydrates_g_per_100g') or nutrition.get('carbohydrates') or 'N/A'}
- Sugars: {nutrition.get('total_sugars_g') or nutrition.get('sugars_100g') or 0}g / 100g
- Total Fat: {nutrition.get('total_fat_g_per_100g') or nutrition.get('total_fat') or 'N/A'}
- Saturated Fat: {nutrition.get('sat_fat_g') or nutrition.get('sat_fat_100g') or 0}g / 100g
- Cholesterol: {nutrition.get('cholesterol_mg_per_100g') or nutrition.get('cholesterol') or '0'}mg
- Protein: {nutrition.get('protein_g') or nutrition.get('protein_100g') or 'N/A'}
- Sodium: {nutrition.get('sodium_mg') or nutrition.get('sodium_100g') or 0}mg / 100g
- Ingredients: {', '.join(product.get('ingredients', [])) if product.get('ingredients') else 'N/A'}
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
