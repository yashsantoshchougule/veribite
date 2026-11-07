"""Personal AI Advisor Chat API endpoint with Citation RAG and deterministic rule fallback."""

import os
from typing import Any, Dict, List, Optional
from fastapi import APIRouter
from pydantic import BaseModel, Field

from backend.core.dosage_engine import calculate_prescribed_dosage
from backend.services.rag_service import (
    build_advisor_rag_context,
    fetch_citations_for_additives,
    synthesize_rule_based_advice,
)

router = APIRouter(prefix="/api/v1/advisor", tags=["Advisor"])


class AdvisorChatRequest(BaseModel):
    product_data: Dict[str, Any] = Field(..., description="Nutritional and additive metadata")
    user_guardrails: Dict[str, Any] = Field(default_factory=dict, description="User health profile & guardrails")
    user_message: str = Field(..., description="User query")


def call_gemini_advisor(prompt: str, user_message: str) -> str:
    """Call Gemini API with strict system instructions and citation groundings."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not configured")

    from google import genai
    client = genai.Client(api_key=api_key)
    model_name = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
    response = client.models.generate_content(
        model=model_name,
        contents=f"{prompt}\n\nUser Question: {user_message}",
    )
    return response.text


@router.post("/chat")
def advisor_chat(request: AdvisorChatRequest) -> Dict[str, Any]:
    """Execute citation-grounded RAG advisor chat with automatic 429/error fallback."""
    product = request.product_data
    guardrails = request.user_guardrails
    user_msg = request.user_message

    additives = product.get("additives", [])
    ins_codes = [str(a.get("ins_code")) for a in additives if a.get("ins_code")]
    citations = fetch_citations_for_additives(ins_codes=ins_codes)

    dosage = calculate_prescribed_dosage(
        nutrition=product.get("nutrition", {}),
        additives=additives,
        user_weight_kg=float(guardrails.get("weight_kg") or 65.0),
        is_child=bool(guardrails.get("is_child", False)),
    )

    try:
        prompt = build_advisor_rag_context(product, guardrails, citations)
        llm_reply = call_gemini_advisor(prompt, user_msg)
        return {
            "source": "gemini_2.5_flash",
            "response": llm_reply,
            "citations": [c["citation_id"] for c in citations],
            "safe_portion_grams": dosage["safe_portion_grams"],
            "frequency_schedule": dosage["frequency_schedule"],
        }
    except Exception:
        synth = synthesize_rule_based_advice(product, guardrails, citations)
        return {
            "source": "rule_based_fallback",
            "response": synth["advice_text"],
            "citations": synth["citations"],
            "safe_portion_grams": synth["safe_portion_grams"],
            "frequency_schedule": synth["frequency_schedule"],
        }
