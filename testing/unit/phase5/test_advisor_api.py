"""Unit tests for Advisor Chat API endpoint and HTTP 429 fallback to Rule-Based Synthesizer."""

from unittest.mock import patch, MagicMock
import pytest
from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)


def test_advisor_chat_rate_limit_fallback_to_synthesizer():
    payload = {
        "product_data": {
            "product_name": "Orange Cream Biscuits",
            "category": "Biscuits",
            "nutrition": {
                "sugar_g_per_100g": 32.0,
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
        },
        "user_guardrails": {
            "weight_kg": 20.0,
            "is_child": True,
            "is_diabetic": True,
            "is_hypertensive": False,
        },
        "user_message": "Can my 5-year-old child eat this biscuit packet?",
    }

    # Simulate Gemini 429 Rate Limit
    with patch("backend.api.advisor.call_gemini_advisor", side_effect=Exception("HTTP 429 ResourceExhausted")):
        response = client.post("/api/v1/advisor/chat", json=payload)
        assert response.status_code == 200
        data = response.json()

        assert data["source"] == "rule_based_fallback"
        assert "Child Safety Alert" in data["response"]
        assert "Diabetic Alert" in data["response"]
        assert data["safe_portion_grams"] == 5
        assert data["frequency_schedule"] == "Complete Avoidance Recommended for Children"


def test_advisor_chat_gemini_success_with_citation_guardrail():
    payload = {
        "product_data": {
            "product_name": "Orange Cream Biscuits",
            "category": "Biscuits",
            "nutrition": {"sugar_g_per_100g": 32.0, "sat_fat_g": 14.0, "sodium_mg": 220.0},
            "additives": [{"ins_code": "110", "primary_name": "Sunset Yellow FCF"}],
        },
        "user_guardrails": {
            "weight_kg": 65.0,
            "is_child": False,
            "is_diabetic": False,
            "is_hypertensive": False,
        },
        "user_message": "What is the acceptable limit for Sunset Yellow?",
    }

    mock_gemini_reply = "According to [JECFA-INS110], Sunset Yellow FCF has an established ADI of 0-4 mg/kg."

    with patch("backend.api.advisor.call_gemini_advisor", return_value=mock_gemini_reply):
        response = client.post("/api/v1/advisor/chat", json=payload)
        assert response.status_code == 200
        data = response.json()

        assert data["source"] == "gemini_2.5_flash"
        assert "[JECFA-INS110]" in data["response"]
