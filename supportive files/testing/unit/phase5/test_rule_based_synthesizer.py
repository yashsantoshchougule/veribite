"""Unit tests for deterministic Rule-Based Regulatory Advisor Synthesizer (HTTP 429 / Outage fallback)."""

import pytest
from backend.services.rag_service import synthesize_rule_based_advice


def test_rule_based_synthesizer_child_and_diabetic_alerts():
    product = {
        "product_name": "Orange Cream Biscuits",
        "category": "Biscuits",
        "nutrition": {
            "sugar_g_per_100g": 32.0,
            "total_sugars_g": 32.0,
            "sat_fat_g_per_100g": 14.0,
            "sodium_mg_per_100g": 220.0,
        },
        "additives": [
            {
                "ins_code": "110",
                "primary_name": "Sunset Yellow FCF",
                "risk_tier": "RED",
                "triggers_red_cap": 1,
                "child_hyperactivity_flag": 1,
                "jecfa_adi_mg_kg": 4.0,
            }
        ],
    }
    guardrails = {
        "weight_kg": 20.0,
        "is_child": True,
        "is_diabetic": True,
        "is_hypertensive": False,
    }
    citations = [
        {
            "citation_id": "JECFA-INS110",
            "authority": "JECFA",
            "ins_code": "110",
            "verified_passage": "Sunset Yellow FCF ADI established at 0-4 mg/kg bw/day.",
        }
    ]

    result = synthesize_rule_based_advice(product, guardrails, citations)

    assert result["source"] == "rule_based_fallback"
    assert "Diabetic Alert" in result["advice_text"]
    assert "Child Safety Alert" in result["advice_text"]
    assert "[JECFA-INS110]" in result["advice_text"]
    assert result["safe_portion_grams"] == 5  # Scaled to 20kg child
    assert result["frequency_schedule"] == "Complete Avoidance Recommended for Children"
