"""Tier 1 Barcode lookup API endpoint with Open Food Facts v2 enrichment proxy."""

import hashlib
import json
from typing import Any, Dict, Optional
from fastapi import APIRouter, HTTPException
import httpx

from backend.core.barcode_normalizer import validate_and_normalize_barcode
from backend.core.product_cache import LocalProductCache
from backend.core.scoring_engine import evaluate_product_verdict
from backend.core.dosage_engine import normalize_and_impute_nutrition

router = APIRouter(prefix="/api/v1", tags=["Products"])

_default_cache: Optional[LocalProductCache] = None


def get_product_cache() -> LocalProductCache:
    """Return default local product cache instance."""
    global _default_cache
    if _default_cache is None:
        _default_cache = LocalProductCache()
        _default_cache.init_table()
    return _default_cache


@router.get("/product/{barcode}")
async def get_product_by_barcode(barcode: str) -> Dict[str, Any]:
    """Tier 1 lookup: check cache/db, or proxy Open Food Facts v2 with Phase 2/3 toxicology enrichment."""
    normalized_barcode = validate_and_normalize_barcode(barcode)
    if not normalized_barcode:
        raise HTTPException(
            status_code=400,
            detail="Invalid barcode format. Expected EAN-13, EAN-8, or UPC-A.",
        )

    cache = get_product_cache()
    cached = cache.get_product(normalized_barcode)
    if cached:
        return {
            "barcode": normalized_barcode,
            "source": "cache",
            "product_name": cached["product_name"],
            "brand_name": cached.get("brand_name"),
            "category": cached.get("category"),
            "serving_size_g": cached.get("serving_size_g"),
            "piece_weight_g": cached.get("piece_weight_g"),
            "nutrition": json.loads(cached["nutrition_json"]),
            "additives": json.loads(cached["additives_json"]),
            "health_score": cached["health_score"],
            "nova_grade": cached["nova_grade"],
            "red_cap_triggered": bool(cached["red_cap_triggered"]),
            "ingredient_hash": cached["ingredient_hash"],
        }

    # Query Open Food Facts API v2
    off_url = f"https://world.openfoodfacts.org/api/v2/product/{normalized_barcode}"
    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(off_url)
            if resp.status_code != 200:
                raise HTTPException(
                    status_code=404,
                    detail="Product not found in barcode registry. Proceed to Tier 2 OCR capture.",
                )
            data = resp.json()
            if data.get("status") != 1 or "product" not in data:
                raise HTTPException(
                    status_code=404,
                    detail="Product not found in barcode registry. Proceed to Tier 2 OCR capture.",
                )
    except httpx.RequestError:
        raise HTTPException(
            status_code=503,
            detail="Barcode lookup service unavailable. Fall back to on-device OCR.",
        )

    product_info = data["product"]
    product_name = product_info.get("product_name") or product_info.get("product_name_en") or "Unknown Product"
    brand_name = product_info.get("brands")
    category = product_info.get("categories")
    ingredients_text = product_info.get("ingredients_text") or ""
    nutriments = product_info.get("nutriments", {})

    # Extract raw nutrients
    raw_nutrition = {
        "energy_kj": nutriments.get("energy-kj_100g") or (
            float(nutriments.get("energy-kcal_100g") or 0.0) * 4.184
        ),
        "total_sugars_g": nutriments.get("sugars_100g"),
        "sat_fat_g": nutriments.get("saturated-fat_100g"),
        "sodium_mg": (float(nutriments["sodium_100g"]) * 1000.0) if nutriments.get("sodium_100g") is not None else None,
        "salt_g": nutriments.get("salt_100g"),
        "fiber_g": nutriments.get("fiber_100g"),
        "protein_g": nutriments.get("proteins_100g"),
        "fruit_veg_nut_pct": nutriments.get("fruits-vegetables-nuts-estimate-from-ingredients_100g") or 0.0,
        "trans_fat_g": nutriments.get("trans-fat_100g") or 0.0,
    }

    # Run imputation and fallback
    norm_nutrition = normalize_and_impute_nutrition(raw_nutrition=raw_nutrition, category=category)

    # Check for Partial Tier 1 (missing ingredient list)
    if not ingredients_text or not ingredients_text.strip():
        return {
            "status": "PARTIAL_TIER_1",
            "barcode": normalized_barcode,
            "source": "openfoodfacts_partial",
            "product_name": product_name,
            "brand_name": brand_name,
            "category": category,
            "serving_size_g": product_info.get("serving_quantity"),
            "piece_weight_g": None,
            "nutrition": norm_nutrition,
            "requires_ocr_ingredient_scan": True,
            "message": "Nutrition table pre-filled from registry. Please scan ingredients list to complete toxicology evaluation.",
        }

    # Empty additives for clean items or parse
    additives: list[Dict[str, Any]] = []

    # Run Phase 3 Scoring Engine
    verdict = evaluate_product_verdict(nutrition=norm_nutrition, additives=additives)

    ing_hash = hashlib.sha256(ingredients_text[:60].encode("utf-8")).hexdigest()

    # Cache product
    cache_record = {
        "barcode": normalized_barcode,
        "product_name": product_name,
        "brand_name": brand_name,
        "category": category,
        "serving_size_g": product_info.get("serving_quantity"),
        "piece_weight_g": None,
        "nutrition_json": json.dumps(norm_nutrition),
        "additives_json": json.dumps(additives),
        "health_score": verdict["final_score"],
        "nova_grade": verdict["nova_grade"],
        "red_cap_triggered": 1 if verdict["red_cap_triggered"] else 0,
        "ingredient_hash": ing_hash,
    }
    cache.set_product(cache_record)

    return {
        "barcode": normalized_barcode,
        "source": "openfoodfacts",
        "product_name": product_name,
        "brand_name": brand_name,
        "category": category,
        "serving_size_g": cache_record["serving_size_g"],
        "piece_weight_g": None,
        "nutrition": norm_nutrition,
        "additives": additives,
        "health_score": verdict["final_score"],
        "nova_grade": verdict["nova_grade"],
        "red_cap_triggered": verdict["red_cap_triggered"],
        "ingredient_hash": ing_hash,
    }

