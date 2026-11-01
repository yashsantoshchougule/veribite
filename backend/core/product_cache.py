"""Local SQLite repository for caching scanned product profiles."""

import sqlite3
from typing import Any, Dict, Optional


class LocalProductCache:
    """Manages on-device and server SQLite cache for instant barcode lookups."""

    def __init__(self, db_path: str = "data_pipeline/toxicology_master.db"):
        self.db_path = db_path

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def init_table(self) -> None:
        """Create local_product_cache table if not exists."""
        conn = self._get_connection()
        try:
            with conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS local_product_cache (
                        barcode TEXT PRIMARY KEY,
                        product_name TEXT NOT NULL,
                        brand_name TEXT,
                        category TEXT,
                        serving_size_g REAL,
                        piece_weight_g REAL,
                        nutrition_json TEXT NOT NULL,
                        additives_json TEXT NOT NULL,
                        health_score INTEGER NOT NULL,
                        nova_grade INTEGER NOT NULL,
                        red_cap_triggered INTEGER NOT NULL DEFAULT 0,
                        ingredient_hash TEXT NOT NULL,
                        cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    );
                    """
                )
        finally:
            conn.close()

    def get_product(self, barcode: str) -> Optional[Dict[str, Any]]:
        """Retrieve cached product by barcode."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT barcode, product_name, brand_name, category,
                       serving_size_g, piece_weight_g, nutrition_json,
                       additives_json, health_score, nova_grade,
                       red_cap_triggered, ingredient_hash, cached_at
                FROM local_product_cache
                WHERE barcode = ?;
                """,
                (barcode,),
            )
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None
        finally:
            conn.close()

    def set_product(self, data: Dict[str, Any]) -> None:
        """Insert or replace product in cache."""
        conn = self._get_connection()
        try:
            with conn:
                conn.execute(
                    """
                    INSERT INTO local_product_cache (
                        barcode, product_name, brand_name, category,
                        serving_size_g, piece_weight_g, nutrition_json,
                        additives_json, health_score, nova_grade,
                        red_cap_triggered, ingredient_hash
                    ) VALUES (
                        :barcode, :product_name, :brand_name, :category,
                        :serving_size_g, :piece_weight_g, :nutrition_json,
                        :additives_json, :health_score, :nova_grade,
                        :red_cap_triggered, :ingredient_hash
                    )
                    ON CONFLICT(barcode) DO UPDATE SET
                        product_name=excluded.product_name,
                        brand_name=excluded.brand_name,
                        category=excluded.category,
                        serving_size_g=excluded.serving_size_g,
                        piece_weight_g=excluded.piece_weight_g,
                        nutrition_json=excluded.nutrition_json,
                        additives_json=excluded.additives_json,
                        health_score=excluded.health_score,
                        nova_grade=excluded.nova_grade,
                        red_cap_triggered=excluded.red_cap_triggered,
                        ingredient_hash=excluded.ingredient_hash,
                        cached_at=CURRENT_TIMESTAMP;
                    """,
                    {
                        "barcode": data["barcode"],
                        "product_name": data["product_name"],
                        "brand_name": data.get("brand_name"),
                        "category": data.get("category"),
                        "serving_size_g": data.get("serving_size_g"),
                        "piece_weight_g": data.get("piece_weight_g"),
                        "nutrition_json": data["nutrition_json"],
                        "additives_json": data["additives_json"],
                        "health_score": data["health_score"],
                        "nova_grade": data["nova_grade"],
                        "red_cap_triggered": data.get("red_cap_triggered", 0),
                        "ingredient_hash": data["ingredient_hash"],
                    },
                )
        finally:
            conn.close()
