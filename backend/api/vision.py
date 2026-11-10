"""Tier 3 Multi-Angle Cloud Gemini 2.5 Flash Vision API endpoint."""

import base64
import json
import os
from typing import Any, Dict, List, Optional
import requests
from dotenv import load_dotenv
from fastapi import APIRouter, File, Form, HTTPException, UploadFile

load_dotenv("backend/.env")

from backend.core.vision_schema import (
    VisionExtractionSchema,
    compute_ingredient_hash,
    check_reformulation,
)
from backend.core.scoring_engine import evaluate_product_verdict
from backend.core.dosage_engine import normalize_and_impute_nutrition
from backend.api.products import get_product_cache

router = APIRouter(prefix="/api/v1", tags=["Vision"])


def extract_vision_with_gemini(image_bytes_list: List[bytes]) -> VisionExtractionSchema:
    """Invoke Gemini Vision with structured Pydantic schema."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        pool = [k.strip() for k in os.getenv("GEMINI_API_KEYS", "").split(",") if k.strip()]
        if pool:
            api_key = pool[0]

    if not api_key:
        raise HTTPException(status_code=503, detail="Gemini API key required for live cloud vision.")

    prompt = """
    Extract structured nutrition facts, ingredients, and product details from this food package photo.
    Return strictly JSON matching this schema:
    {
      "product_name": "Product Name",
      "brand_name": "Brand",
      "food_category": "Snacks",
      "net_weight_g": 100.0,
      "serving_size_g": 20.0,
      "piece_weight_g": 10.0,
      "front_pack_claims": [],
      "raw_ingredients_ordered": ["Ingredient 1", "Ingredient 2"],
      "declared_ins_codes": ["110", "211"],
      "nutrition_per_100g": {
        "energy_kj": 1500.0,
        "total_sugars_g": 20.0,
        "sat_fat_g": 5.0,
        "trans_fat_g": 0.0,
        "sodium_mg": 300.0,
        "fiber_g": 2.0,
        "protein_g": 4.0
      }
    }
    """
    parts = [{"text": prompt}]
    for b in image_bytes_list:
        parts.append({
            "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64.b64encode(b).decode("utf-8")
            }
        })

    models_to_try = ["gemini-3.1-flash-lite", "gemini-3.5-flash-lite", "gemini-flash-latest"]
    for model in models_to_try:
        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
            payload = {
                "contents": [{"parts": parts}],
                "generationConfig": {
                    "temperature": 0.1,
                    "responseMimeType": "application/json"
                }
            }
            res = requests.post(url, json=payload, timeout=15)
            if res.status_code == 200:
                data = res.json()
                text = data["candidates"][0]["content"]["parts"][0]["text"]
                parsed = json.loads(text)
                return VisionExtractionSchema(**parsed)
        except Exception:
            continue

    raise HTTPException(status_code=502, detail="Gemini Vision service temporarily unavailable.")


@router.post("/scan/vision")
async def process_multi_angle_vision(
    images: List[UploadFile] = File(...),
    barcode: Optional[str] = Form(None),
) -> Dict[str, Any]:
    """Process 1-4 WebP images with Gemini 2.5 Flash, execute deterministic math, and auto-cache."""
    if len(images) < 1 or len(images) > 4:
        raise HTTPException(status_code=400, detail="Must provide between 1 and 4 image frames.")

    image_bytes: List[bytes] = []
    for img in images:
        content = await img.read()
        image_bytes.append(content)

    # Extract schema from Gemini 2.5 Flash
    extracted = extract_vision_with_gemini(image_bytes)

    # Normalize nutrition
    norm_nutrition = normalize_and_impute_nutrition(
        raw_nutrition=extracted.nutrition_per_100g,
        ingredients_ordered=extracted.raw_ingredients_ordered,
        category=extracted.food_category,
    )

    # Enrich declared INS codes
    additives: List[Dict[str, Any]] = []
    red_dye_codes = {"102", "104", "110", "122", "124", "129"}
    for code in extracted.declared_ins_codes:
        is_red = code in red_dye_codes
        additives.append({
            "ins_code": code,
            "primary_name": f"Additive INS {code}",
            "risk_tier": "RED" if is_red else "CAUTION",
            "triggers_red_cap": 1 if is_red else 0,
            "child_hyperactivity_flag": 1 if is_red else 0,
            "jecfa_adi_mg_kg": 4.0 if is_red else 10.0,
        })

    # Evaluate verdict
    verdict = evaluate_product_verdict(
        nutrition=norm_nutrition,
        additives=additives,
        ingredient_count=len(extracted.raw_ingredients_ordered),
    )

    # Reformulation check
    current_hash = compute_ingredient_hash(extracted.raw_ingredients_ordered)
    reformulation_detected = False

    cache = get_product_cache()
    if barcode:
        cached = cache.get_product(barcode)
        if cached:
            reformulation_detected = check_reformulation(cached.get("ingredient_hash"), extracted.raw_ingredients_ordered)

        # Write through to cache
        cache.set_product({
            "barcode": barcode,
            "product_name": extracted.product_name,
            "brand_name": extracted.brand_name,
            "category": extracted.food_category,
            "serving_size_g": extracted.serving_size_g,
            "piece_weight_g": extracted.piece_weight_g,
            "nutrition_json": json.dumps(norm_nutrition),
            "additives_json": json.dumps(additives),
            "health_score": verdict["final_score"],
            "nova_grade": verdict["nova_grade"],
            "red_cap_triggered": 1 if verdict["red_cap_triggered"] else 0,
            "ingredient_hash": current_hash,
        })

    return {
        "source": "gemini_vision",
        "barcode": barcode,
        "product_name": extracted.product_name,
        "brand_name": extracted.brand_name,
        "category": extracted.food_category,
        "serving_size_g": extracted.serving_size_g,
        "piece_weight_g": extracted.piece_weight_g,
        "nutrition": norm_nutrition,
        "additives": additives,
        "health_score": verdict["final_score"],
        "final_score": verdict["final_score"],
        "nova_grade": verdict["nova_grade"],
        "red_cap_triggered": verdict["red_cap_triggered"],
        "red_cap_reason": verdict["red_cap_reason"],
        "reformulation_detected": reformulation_detected,
        "ingredient_hash": current_hash,
    }
