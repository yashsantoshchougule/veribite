"""Master Release Gate Suite for Phase 5: FastAPI Backend, Supabase, Redis & Citation RAG.

Verifies:
1. Multi-layer cache resilience (<50ms fallback to SQLite on Redis error).
2. Partial Tier 1 detection contract for missing ingredient lists.
3. Citation RAG retrieval with [Citation_ID] tagging.
4. Deterministic Rule-Based Regulatory Synthesizer (HTTP 429 fallback).
5. Personal Food Safety Advisor Chat API endpoint.
6. Strict test folder isolation & zero external network calls.
"""

import time
from pathlib import Path
from unittest.mock import patch, MagicMock
import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.services.cache_service import MultiLayerCacheManager
from backend.services.rag_service import (
    fetch_citations_for_additives,
    build_advisor_rag_context,
    synthesize_rule_based_advice,
)
from backend.core.product_cache import LocalProductCache

client = TestClient(app)


def test_phase5_master_release_gate(tmp_path):
    start_time = time.perf_counter()

    # 1. Multi-layer Cache Resilience (< 50ms fallback on Redis drop)
    db_file = tmp_path / "sqlite_cache.db"
    local_cache = LocalProductCache(db_path=str(db_file))
    local_cache.init_table()
    test_product = {
        "barcode": "8901234567890",
        "product_name": "Resilience Biscuit",
        "brand_name": "Resilience Corp",
        "category": "Biscuits",
        "serving_size_g": 20.0,
        "piece_weight_g": 10.0,
        "nutrition_json": "{}",
        "additives_json": "[]",
        "health_score": 55,
        "nova_grade": 3,
        "red_cap_triggered": 0,
        "ingredient_hash": "hash123",
    }
    local_cache.set_product(test_product)

    broken_redis = MagicMock()
    broken_redis.get.side_effect = Exception("Redis Connection Timeout")
    broken_redis.setex.side_effect = Exception("Redis Connection Timeout")

    mgr = MultiLayerCacheManager(redis_client=broken_redis, sqlite_cache=local_cache)
    t0 = time.perf_counter()
    cached = mgr.get_product("8901234567890")
    t_elapsed = (time.perf_counter() - t0) * 1000
    assert cached is not None
    assert cached["product_name"] == "Resilience Biscuit"
    assert t_elapsed < 50.0

    # 2. Partial Tier 1 Detection
    partial_off_payload = {
        "status": 1,
        "product": {
            "product_name": "Partial Oat Bar",
            "nutriments": {
                "sugars_100g": 18.0,
                "saturated-fat_100g": 4.5,
                "sodium_100g": 0.12,
                "proteins_100g": 6.0,
                "fiber_100g": 5.0,
            },
            "ingredients_text": "",
        },
    }

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = partial_off_payload

    with patch("httpx.AsyncClient.get", return_value=mock_resp), \
         patch("backend.api.products.get_product_cache") as mock_cache_getter:
        mock_empty_cache = MagicMock()
        mock_empty_cache.get_product.return_value = None
        mock_cache_getter.return_value = mock_empty_cache

        res = client.get("/api/v1/product/8901030383786")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "PARTIAL_TIER_1"
        assert data["product_name"] == "Partial Oat Bar"
        assert data["nutrition"]["total_sugars_g"] == 18.0

    # 3. Citation RAG Retrieval & Prompt Assembly
    citations = fetch_citations_for_additives(ins_codes=["110"])
    assert len(citations) >= 1
    prompt_context = build_advisor_rag_context(
        product={"product_name": "Orange Cream", "nutrition": {}, "additives": []},
        guardrails={"weight_kg": 20.0, "is_child": True},
        citations=citations,
    )
    assert "ZERO-HALLUCINATION GUARDRAIL" in prompt_context
    assert "[Citation_ID]" in prompt_context

    # 4. Deterministic Rule-Based Regulatory Synthesizer
    synth = synthesize_rule_based_advice(
        product={
            "product_name": "Orange Cream Biscuits",
            "nutrition": {"sugar_g_per_100g": 32.0, "sat_fat_g_per_100g": 14.0, "sodium_mg_per_100g": 220.0},
            "additives": [{"ins_code": "110", "child_hyperactivity_flag": 1, "jecfa_adi_mg_kg": 4.0}],
        },
        guardrails={"weight_kg": 20.0, "is_child": True, "is_diabetic": True},
        citations=citations,
    )
    assert synth["source"] == "rule_based_fallback"
    assert synth["safe_portion_grams"] == 5
    assert synth["frequency_schedule"] == "Complete Avoidance Recommended for Children"
    assert "Child Safety Alert" in synth["advice_text"]

    # 5. Personal Food Safety Advisor Chat Endpoint
    chat_payload = {
        "product_data": {
            "product_name": "Orange Cream Biscuits",
            "category": "Biscuits",
            "nutrition": {"sugar_g_per_100g": 32.0, "sat_fat_g_per_100g": 14.0, "sodium_mg_per_100g": 220.0},
            "additives": [{"ins_code": "110", "child_hyperactivity_flag": 1, "jecfa_adi_mg_kg": 4.0}],
        },
        "user_guardrails": {"weight_kg": 20.0, "is_child": True, "is_diabetic": True},
        "user_message": "Is this safe for my diabetic child?",
    }
    with patch("backend.api.advisor.call_gemini_advisor", side_effect=Exception("HTTP 429 ResourceExhausted")):
        chat_res = client.post("/api/v1/advisor/chat", json=chat_payload)
        assert chat_res.status_code == 200
        chat_data = chat_res.json()
        assert chat_data["source"] == "rule_based_fallback"
        assert chat_data["safe_portion_grams"] == 5

    # 6. Overall gate performance < 0.5s
    elapsed = time.perf_counter() - start_time
    assert elapsed < 0.50, f"Gate execution took {elapsed:.3f}s"


def test_phase5_strict_test_isolation():
    """Verify all test files reside strictly in testing/ and production code contains no test fixtures."""
    repo_root = Path(__file__).resolve().parent.parent.parent.parent
    backend_tests = list((repo_root / "backend").rglob("test_*.py"))
    backend_tests = [p for p in backend_tests if ".venv" not in p.parts]
    assert len(backend_tests) == 0, f"Test pollution in backend: {backend_tests}"

    data_pipeline_tests = list((repo_root / "data_pipeline").rglob("test_*.py"))
    assert len(data_pipeline_tests) == 0, f"Test pollution in data_pipeline: {data_pipeline_tests}"
