"""Unit tests for Citation RAG Context Assembly and SQLite Regulatory Citations query."""

import sqlite3
import pytest
from backend.services.rag_service import (
    fetch_citations_for_additives,
    build_advisor_rag_context,
)


def test_fetch_citations_from_sqlite(tmp_path):
    db_file = tmp_path / "test_citations.db"
    conn = sqlite3.connect(db_file)
    with conn:
        conn.execute("""
            CREATE TABLE regulatory_citations (
                citation_id TEXT PRIMARY KEY,
                authority TEXT NOT NULL,
                ins_code TEXT,
                verified_passage TEXT,
                source_url TEXT
            );
        """)
        conn.execute("""
            INSERT INTO regulatory_citations VALUES
            ('JECFA-INS110', 'JECFA', '110', 'Sunset Yellow FCF ADI established at 0-4 mg/kg bw/day.', 'https://who.int/jecfa/110'),
            ('FSSAI-SYN-COLOUR', 'FSSAI', '110', 'Maximum permitted level in biscuits is 100 mg/kg.', 'https://fssai.gov.in/std/colours'),
            ('WHO-SUGAR-2015', 'WHO', NULL, 'Free sugars should be less than 10% of total energy intake, ideally < 5%.', 'https://who.int/sugar');
        """)
    conn.close()

    citations = fetch_citations_for_additives(str(db_file), ["110"])
    assert len(citations) >= 2
    authorities = {c["authority"] for c in citations}
    assert "JECFA" in authorities
    assert "FSSAI" in authorities


def test_build_advisor_rag_context():
    product = {
        "product_name": "Orange Cream Biscuits",
        "category": "Biscuits",
        "nutrition": {"total_sugars_g": 32.0, "sat_fat_g": 14.0, "sodium_mg": 220.0},
        "additives": [{"ins_code": "110", "primary_name": "Sunset Yellow FCF"}],
    }
    user_guardrails = {
        "weight_kg": 20.0,
        "is_child": True,
        "is_diabetic": False,
        "is_hypertensive": False,
    }
    citations = [
        {
            "citation_id": "JECFA-INS110",
            "authority": "JECFA",
            "verified_passage": "Sunset Yellow FCF ADI established at 0-4 mg/kg bw/day.",
        }
    ]

    prompt_context = build_advisor_rag_context(product, user_guardrails, citations)
    assert "Orange Cream Biscuits" in prompt_context
    assert "Weight: 20.0kg" in prompt_context
    assert "Child Profile: YES" in prompt_context
    assert "[JECFA-INS110]" in prompt_context
    assert "ZERO-HALLUCINATION GUARDRAIL" in prompt_context
