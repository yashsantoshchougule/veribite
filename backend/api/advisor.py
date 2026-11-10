"""Personal AI Advisor Chat API endpoint with Citation RAG and deterministic rule fallback."""

import json
import os
from typing import Any, Dict, List, Optional
import requests
from dotenv import load_dotenv
from fastapi import APIRouter
from pydantic import BaseModel, Field

load_dotenv("backend/.env")

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
        pool = [k.strip() for k in os.getenv("GEMINI_API_KEYS", "").split(",") if k.strip()]
        if pool:
            api_key = pool[0]
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not configured")

    models_to_try = [
        os.getenv("GEMINI_MODEL", "gemini-3.1-flash-lite"),
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
    ]

    for model in models_to_try:
        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
            payload = {
                "contents": [
                    {
                        "parts": [
                            {"text": f"{prompt}\n\nUser Question: {user_message}"}
                        ]
                    }
                ],
                "generationConfig": {
                    "temperature": 0.2,
                }
            }
            res = requests.post(url, json=payload, timeout=12)
            if res.status_code == 200:
                data = res.json()
                return data["candidates"][0]["content"]["parts"][0]["text"]
        except Exception:
            continue

    raise RuntimeError("All Gemini Advisor models failed or timed out.")


@router.post("/chat")
def advisor_chat(request: AdvisorChatRequest) -> Dict[str, Any]:
    """Execute citation-grounded RAG advisor chat with automatic 429/error fallback."""
    product = request.product_data
    guardrails = request.user_guardrails
    user_msg = request.user_message
    lower_msg = user_msg.lower().strip()

    # Guardrail 1: Out-of-scope query refusal
    out_of_scope_keywords = ["pm of", "prime minister", "president", "weather in", "cricket", "who won", "write code", "python code", "tell me a joke"]
    if any(k in lower_msg for k in out_of_scope_keywords):
        return {
            "source": "veribite_guardrail",
            "response": "I am the VeriBite Food Safety & App Advisor. I can only assist with questions about packaged food ingredients, nutrition, chemical additives (INS), safe portions, or using the VeriBite app. Please ask a question related to food products or this application!",
            "citations": [],
            "safe_portion_grams": None,
            "frequency_schedule": None,
        }

    # Guardrail 2: Model & creator identity anonymity
    identity_keywords = ["which model", "what model", "who created you", "who made you", "are you gemini", "are you chatgpt", "what ai are you"]
    if any(k in lower_msg for k in identity_keywords):
        return {
            "source": "veribite_guardrail",
            "response": "I am the VeriBite AI Advisor, built into the VeriBite application to help you evaluate packaged food ingredients, chemical toxicology, safe consumption dosage, and in-app features. How can I help you evaluate your food or navigate the app today?",
            "citations": [],
            "safe_portion_grams": None,
            "frequency_schedule": None,
        }

    additives = product.get("additives", [])
    ins_codes = [str(a.get("ins_code")) for a in additives if a.get("ins_code")]
    citations = fetch_citations_for_additives(ins_codes=ins_codes)

    dosage = calculate_prescribed_dosage(
        nutrition=product.get("nutrition", {}),
        additives=additives,
        user_weight_kg=float(guardrails.get("weight_kg") or 65.0),
        is_child=bool(guardrails.get("is_child", False)),
    )

    has_product = bool(product.get("product_name") and product.get("product_name") != "General Food Toxicology" and product.get("nutrition"))
    portion_keywords = ["portion", "how much", "serving", "dose", "dosage", "grams", "can i eat", "safe to eat", "limit", "intake", "how many", "limit"]
    is_portion_relevant = any(k in lower_msg for k in portion_keywords) or (has_product and any(k in lower_msg for k in ["safe", "kid", "child", "diabet", "sugar", "eat"]))

    try:
        prompt = build_advisor_rag_context(product, guardrails, citations)
        llm_reply = call_gemini_advisor(prompt, user_msg)
        return {
            "source": "gemini_2.5_flash",
            "response": llm_reply,
            "citations": [c["citation_id"] for c in citations],
            "safe_portion_grams": dosage["safe_portion_grams"] if is_portion_relevant else None,
            "frequency_schedule": dosage["frequency_schedule"] if is_portion_relevant else None,
        }
    except Exception:
        synth = synthesize_rule_based_advice(product, guardrails, citations)
        return {
            "source": "rule_based_fallback",
            "response": synth["advice_text"],
            "citations": synth["citations"],
            "safe_portion_grams": synth["safe_portion_grams"] if is_portion_relevant else None,
            "frequency_schedule": synth["frequency_schedule"] if is_portion_relevant else None,
        }
