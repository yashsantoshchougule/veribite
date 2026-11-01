"""Strict Gemini 2.5 Flash Vision Pydantic Contract and reformulation tracking."""

import hashlib
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class VisionExtractionSchema(BaseModel):
    """Strict schema returned by Gemini 2.5 Flash for multi-angle packet frames."""

    product_name: str = Field(description="Commercial product name")
    brand_name: Optional[str] = Field(default=None, description="Brand or manufacturer")
    food_category: str = Field(default="Snacks", description="Food category e.g. Biscuits, Beverage, Namkeen")
    net_weight_g: Optional[float] = Field(default=None, description="Net packet weight in grams")
    serving_size_g: Optional[float] = Field(default=None, description="Declared single serving size in grams")
    piece_weight_g: Optional[float] = Field(default=None, description="Weight of single piece or biscuit in grams")
    front_pack_claims: List[str] = Field(default_factory=list, description="Marketing claims e.g. 'No Added Sugar'")
    raw_ingredients_ordered: List[str] = Field(description="Ingredient list strictly in printed order")
    declared_ins_codes: List[str] = Field(default_factory=list, description="Normalized INS / E-codes")
    nutrition_per_100g: Dict[str, Optional[float]] = Field(
        description="Per-100g values: energy_kj, total_sugars_g, sat_fat_g, trans_fat_g, sodium_mg, fiber_g, protein_g"
    )


def compute_ingredient_hash(ingredients: Any) -> str:
    """Compute SHA-256 hash of first 60 characters of ingredient list for reformulation detection."""
    if isinstance(ingredients, list):
        text = ", ".join(ingredients)
    else:
        text = str(ingredients or "")
    normalized = " ".join(text[:60].strip().lower().split())
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def check_reformulation(cached_hash: Optional[str], current_ingredients: Any) -> bool:
    """Return True if manufacturer reformulated product recipe under same barcode."""
    if not cached_hash:
        return False
    current_hash = compute_ingredient_hash(current_ingredients)
    return current_hash != cached_hash

