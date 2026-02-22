import asyncpg
import os
from typing import Optional, List, Dict, Any
from datetime import date
import uuid

# Get database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL")


async def get_db_pool():
    """Create and return a database connection pool."""
    return await asyncpg.create_pool(DATABASE_URL)


class DatabaseService:
    """Service for database operations."""

    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    # ==================== STORES ====================

    async def get_store_by_name(self, store_name: str) -> Optional[Dict[str, Any]]:
        """Get store by name."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM stores WHERE store_name = $1",
                store_name
            )
            return dict(row) if row else None

    async def create_store(self, store_name: str, logo_url: Optional[str] = None) -> str:
        """Create a new store and return its ID."""
        store_id = str(uuid.uuid4())
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO stores (store_id, store_name, logo_url)
                VALUES ($1, $2, $3)
                ON CONFLICT (store_name) DO NOTHING
                """,
                store_id, store_name, logo_url
            )
        return store_id

    async def get_or_create_store(self, store_name: str, logo_url: Optional[str] = None) -> str:
        """Get store ID or create if not exists."""
        store = await self.get_store_by_name(store_name)
        if store:
            return store["store_id"]
        return await self.create_store(store_name, logo_url)

    # ==================== PRODUCTS ====================

    async def get_product_by_barcode(self, barcode: str) -> Optional[Dict[str, Any]]:
        """Get product by barcode."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM products WHERE barcode = $1",
                barcode
            )
            return dict(row) if row else None

    async def upsert_product(
        self,
        barcode: str,
        product_name: str,
        brand: Optional[str] = None,
        energy_kcal: Optional[float] = None,
        proteins_g: Optional[float] = None,
        carbohydrates_g: Optional[float] = None,
        sugars_g: Optional[float] = None,
        fat_g: Optional[float] = None,
        nutriscore_grade: Optional[str] = None,
        nova_group: Optional[int] = None,
        allergens: Optional[List[str]] = None,
        image_url: Optional[str] = None
    ) -> str:
        """Insert or update a product, return product_id."""
        async with self.pool.acquire() as conn:
            # Check if product exists
            existing = await conn.fetchrow(
                "SELECT product_id FROM products WHERE barcode = $1",
                barcode
            )

            if existing:
                # Update existing product
                await conn.execute(
                    """
                    UPDATE products SET
                        product_name = COALESCE($2, product_name),
                        brand = COALESCE($3, brand),
                        energy_kcal = COALESCE($4, energy_kcal),
                        proteins_g = COALESCE($5, proteins_g),
                        carbohydrates_g = COALESCE($6, carbohydrates_g),
                        sugars_g = COALESCE($7, sugars_g),
                        fat_g = COALESCE($8, fat_g),
                        nutriscore_grade = COALESCE($9, nutriscore_grade),
                        nova_group = COALESCE($10, nova_group),
                        allergens = COALESCE($11, allergens),
                        image_url = COALESCE($12, image_url)
                    WHERE barcode = $1
                    """,
                    barcode, product_name, brand, energy_kcal, proteins_g,
                    carbohydrates_g, sugars_g, fat_g, nutriscore_grade,
                    nova_group, allergens, image_url
                )
                return str(existing["product_id"])
            else:
                # Insert new product
                product_id = str(uuid.uuid4())
                await conn.execute(
                    """
                    INSERT INTO products (
                        product_id, barcode, product_name, brand,
                        energy_kcal, proteins_g, carbohydrates_g, sugars_g, fat_g,
                        nutriscore_grade, nova_group, allergens, image_url
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
                    """,
                    product_id, barcode, product_name, brand,
                    energy_kcal, proteins_g, carbohydrates_g, sugars_g, fat_g,
                    nutriscore_grade, nova_group, allergens, image_url
                )
                return product_id

    # ==================== PROMOTIONS ====================

    async def create_promotion(
        self,
        store_id: str,
        product_id: Optional[str],
        barcode: str,
        product_name: str,
        discount_label: Optional[str],
        valid_from: date,
        valid_until: date,
        original_price: Optional[float] = None,
        promo_price: Optional[float] = None,
        category: Optional[str] = None,
        primary_macro: Optional[str] = None,
        is_healthy: bool = False,
    ) -> str:
        """Create a new promotion. discount_label is the raw text like '1+1 GRATIS', '-50%'."""
        promo_id = str(uuid.uuid4())

        # promo_price is NOT NULL in the database, use 0.0 as default
        if promo_price is None:
            promo_price = 0.0

        # Default category and macro if not provided
        if not category:
            category = "Overig"
        if not primary_macro:
            primary_macro = "None"

        try:
            async with self.pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO promotions (
                        promo_id, store_id, product_id, barcode, product_name,
                        original_price, promo_price, discount_percentage,
                        valid_from, valid_until, is_active,
                        category, primary_macro, is_healthy
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, true, $11, $12, $13)
                    """,
                    promo_id, store_id, product_id, barcode, product_name,
                    original_price, promo_price, discount_label,
                    valid_from, valid_until,
                    category, primary_macro, is_healthy,
                )
            print(f"Created promotion {promo_id} for {barcode} [{category}]")
            return promo_id
        except Exception as e:
            print(f"ERROR creating promotion for {barcode}: {e}")
            raise e

    async def deactivate_old_promotions(self, store_id: str) -> int:
        """Deactivate promotions that have expired."""
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                """
                UPDATE promotions
                SET is_active = false
                WHERE store_id = $1 AND valid_until < CURRENT_DATE
                """,
                store_id
            )
            # Extract count from result string like "UPDATE 5"
            return int(result.split()[-1]) if result else 0

    async def get_active_promotions(self, store_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get active promotions, optionally filtered by store."""
        async with self.pool.acquire() as conn:
            if store_id:
                rows = await conn.fetch(
                    """
                    SELECT p.*, s.store_name
                    FROM promotions p
                    JOIN stores s ON p.store_id = s.store_id
                    WHERE p.store_id = $1 AND p.is_active = true
                    ORDER BY p.valid_until
                    """,
                    store_id
                )
            else:
                rows = await conn.fetch(
                    """
                    SELECT p.*, s.store_name
                    FROM promotions p
                    JOIN stores s ON p.store_id = s.store_id
                    WHERE p.is_active = true
                    ORDER BY p.valid_until
                    """
                )
            return [dict(row) for row in rows]

    async def get_active_promotions_by_store_name(self, store_name: str) -> List[Dict[str, Any]]:
        """Get active promotions filtered by store name (case-insensitive)."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT p.*, s.store_name
                FROM promotions p
                JOIN stores s ON p.store_id = s.store_id
                WHERE p.is_active = true
                  AND LOWER(s.store_name) = LOWER($1)
                ORDER BY p.valid_until
                """,
                store_name
            )
            return [dict(row) for row in rows]


# Global pool instance
_pool: Optional[asyncpg.Pool] = None


async def get_database_service() -> DatabaseService:
    """Get or create database service instance."""
    global _pool
    if _pool is None:
        _pool = await get_db_pool()
    return DatabaseService(_pool)


async def close_database_pool():
    """Close the database pool."""
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
