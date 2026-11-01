"""Supabase PostgreSQL cloud persistence service with graceful offline fallback."""

import logging
import os
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)


class SupabaseProductService:
    """Manages cloud persistence of products in Supabase PostgreSQL."""

    def __init__(
        self,
        client: Optional[Any] = None,
        url: Optional[str] = None,
        key: Optional[str] = None,
    ):
        if client is not None:
            self.client = client
        else:
            supabase_url = url or os.getenv("SUPABASE_URL")
            supabase_key = key or os.getenv("SUPABASE_KEY")
            if supabase_url and supabase_key:
                try:
                    from supabase import create_client
                    self.client = create_client(supabase_url, supabase_key)
                except Exception as e:
                    logger.warning(f"Failed to initialize Supabase client: {e}")
                    self.client = None
            else:
                self.client = None

    def get_product(self, barcode: str) -> Optional[Dict[str, Any]]:
        """Retrieve product by barcode from Supabase 'products' table."""
        if not self.client:
            return None
        try:
            response = (
                self.client.table("products")
                .select("*")
                .eq("barcode", barcode)
                .execute()
            )
            data = getattr(response, "data", None)
            if data and len(data) > 0:
                return data[0]
            return None
        except Exception as e:
            logger.warning(f"Supabase get_product failed: {e}")
            return None

    def upsert_product(self, product_data: Dict[str, Any]) -> bool:
        """Insert or update product record in Supabase 'products' table."""
        if not self.client:
            return False
        try:
            response = (
                self.client.table("products")
                .upsert(product_data)
                .execute()
            )
            return bool(getattr(response, "data", False))
        except Exception as e:
            logger.warning(f"Supabase upsert_product failed: {e}")
            return False
