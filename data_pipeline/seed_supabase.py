"""Seed Supabase PostgreSQL database with realistic sample packaged products and user data."""

import hashlib
import json
import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")

if not supabase_url or not supabase_key:
    raise RuntimeError("SUPABASE_URL and SUPABASE_KEY must be set in .env")

client = create_client(supabase_url, supabase_key)


def compute_hash(text: str) -> str:
    return hashlib.sha256(text.strip().lower()[:60].encode("utf-8")).hexdigest()


DUMMY_PRODUCTS = [
    {
        "barcode": "8901030383786",
        "product_name": "Orange Cream Biscuits",
        "brand_name": "Britannia Treat",
        "category": "Biscuits",
        "serving_size_g": 20.0,
        "piece_weight_g": 10.0,
        "nutrition_json": {
            "energy_kcal": 478.0,
            "sugar_g_per_100g": 32.0,
            "total_sugars_g": 32.0,
            "sat_fat_g_per_100g": 14.0,
            "sat_fat_g": 14.0,
            "sodium_mg_per_100g": 220.0,
            "sodium_mg": 220.0,
            "protein_g": 4.5,
            "fiber_g": 1.2,
        },
        "additives_json": [
            {
                "ins_code": "110",
                "primary_name": "Sunset Yellow FCF",
                "risk_tier": "RED",
                "triggers_red_cap": 1,
                "jecfa_adi_mg_kg": 4.0,
                "child_hyperactivity_flag": 1,
                "citation_id": "JECFA_SUNSET_YELLOW_2011",
            },
            {
                "ins_code": "503ii",
                "primary_name": "Ammonium Hydrogen Carbonate",
                "risk_tier": "SAFE",
                "triggers_red_cap": 0,
            },
        ],
        "health_score": 22,
        "nova_grade": 4,
        "red_cap_triggered": 1,
        "ingredient_hash": compute_hash("Refined Wheat Flour, Sugar, Palm Oil, Food Colour (INS 110)"),
    },
    {
        "barcode": "8901234567890",
        "product_name": "100% Wholegrain Rolled Oats",
        "brand_name": "Quaker",
        "category": "Breakfast Cereals",
        "serving_size_g": 40.0,
        "piece_weight_g": 40.0,
        "nutrition_json": {
            "energy_kcal": 380.0,
            "sugar_g_per_100g": 1.1,
            "total_sugars_g": 1.1,
            "sat_fat_g_per_100g": 1.5,
            "sat_fat_g": 1.5,
            "sodium_mg_per_100g": 5.0,
            "sodium_mg": 5.0,
            "protein_g": 12.5,
            "fiber_g": 10.0,
        },
        "additives_json": [],
        "health_score": 88,
        "nova_grade": 1,
        "red_cap_triggered": 0,
        "ingredient_hash": compute_hash("100% Whole Grain Rolled Oats"),
    },
    {
        "barcode": "8901764012234",
        "product_name": "Classic Sparkling Cola",
        "brand_name": "Thums Up",
        "category": "Beverages",
        "serving_size_g": 250.0,
        "piece_weight_g": 250.0,
        "nutrition_json": {
            "energy_kcal": 44.0,
            "sugar_g_per_100g": 10.6,
            "total_sugars_g": 10.6,
            "sat_fat_g_per_100g": 0.0,
            "sat_fat_g": 0.0,
            "sodium_mg_per_100g": 15.0,
            "sodium_mg": 15.0,
            "protein_g": 0.0,
            "fiber_g": 0.0,
        },
        "additives_json": [
            {
                "ins_code": "150d",
                "primary_name": "Sulphite Ammonia Caramel (Caramel IV)",
                "risk_tier": "CAUTION",
                "triggers_red_cap": 0,
                "citation_id": "FSSAI_LABELLING_2020",
            },
            {
                "ins_code": "338",
                "primary_name": "Phosphoric Acid",
                "risk_tier": "CAUTION",
                "triggers_red_cap": 0,
            },
        ],
        "health_score": 18,
        "nova_grade": 4,
        "red_cap_triggered": 0,
        "ingredient_hash": compute_hash("Carbonated Water, Sugar, Acidity Regulator (INS 338), Colour (INS 150d)"),
    },
    {
        "barcode": "8901491101831",
        "product_name": "Classic Salted Potato Chips",
        "brand_name": "Lay's",
        "category": "Savory Snacks",
        "serving_size_g": 30.0,
        "piece_weight_g": 30.0,
        "nutrition_json": {
            "energy_kcal": 545.0,
            "sugar_g_per_100g": 1.2,
            "total_sugars_g": 1.2,
            "sat_fat_g_per_100g": 12.8,
            "sat_fat_g": 12.8,
            "sodium_mg_per_100g": 620.0,
            "sodium_mg": 620.0,
            "protein_g": 6.8,
            "fiber_g": 3.5,
        },
        "additives_json": [],
        "health_score": 36,
        "nova_grade": 3,
        "red_cap_triggered": 0,
        "ingredient_hash": compute_hash("Potato, Edible Vegetable Oil, Salt"),
    },
    {
        "barcode": "8901058852219",
        "product_name": "2-Minute Masala Noodles",
        "brand_name": "Maggi",
        "category": "Instant Noodles",
        "serving_size_g": 70.0,
        "piece_weight_g": 70.0,
        "nutrition_json": {
            "energy_kcal": 435.0,
            "sugar_g_per_100g": 2.2,
            "total_sugars_g": 2.2,
            "sat_fat_g_per_100g": 6.8,
            "sat_fat_g": 6.8,
            "sodium_mg_per_100g": 860.0,
            "sodium_mg": 860.0,
            "protein_g": 8.0,
            "fiber_g": 3.6,
        },
        "additives_json": [
            {
                "ins_code": "621",
                "primary_name": "Monosodium Glutamate (MSG)",
                "risk_tier": "CAUTION",
                "triggers_red_cap": 0,
                "citation_id": "FSSAI_LABELLING_2020",
            }
        ],
        "health_score": 34,
        "nova_grade": 4,
        "red_cap_triggered": 0,
        "ingredient_hash": compute_hash("Wheat Flour, Palm Oil, Salt, Flavour Enhancer (INS 621)"),
    },
]


def seed_database():
    print(f"Connecting to Supabase: {supabase_url}")

    # 1. Upsert Products
    print(f"Upserting {len(DUMMY_PRODUCTS)} sample products...")
    for prod in DUMMY_PRODUCTS:
        res = client.table("products").upsert(prod).execute()
        print(f"  + Added [{prod['barcode']}] {prod['brand_name']} - {prod['product_name']} (Score: {prod['health_score']})")

    # 2. Add sample user profile
    sample_device_id = "device_test_demo_01"
    user_profile = {
        "device_id": sample_device_id,
        "weight_kg": 65.0,
        "is_child": False,
        "is_diabetic": False,
        "is_hypertensive": False,
    }
    client.table("user_profiles").upsert(user_profile, on_conflict="device_id").execute()
    print(f"  + Added Sample Profile for device: {sample_device_id}")

    # 3. Add sample scan history
    scan_history = [
        {"device_id": sample_device_id, "barcode": "8901030383786"},
        {"device_id": sample_device_id, "barcode": "8901234567890"},
    ]
    for scan in scan_history:
        client.table("scan_history").insert(scan).execute()
    print(f"  + Added 2 scan history records for device: {sample_device_id}")

    print("\nSupabase Database Seeding Complete!")


if __name__ == "__main__":
    seed_database()
