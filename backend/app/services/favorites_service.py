import uuid
from app.services.database_service import get_database_service


async def get_favorites(user_id: str) -> list[dict]:
    """Haal alle favoriete producten op van een gebruiker."""
    db = await get_database_service()
    async with db.pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT f.favorite_id, f.created_at,
                   p.product_id, p.barcode, p.product_name, p.brand,
                   p.energy_kcal, p.proteins_g, p.carbohydrates_g,
                   p.fat_g, p.nutriscore_grade, p.image_url
            FROM user_favorites f
            JOIN products p ON f.product_id = p.product_id
            WHERE f.user_id = $1
            ORDER BY f.created_at DESC
            """,
            user_id,
        )
        return [dict(row) for row in rows]


async def add_favorite(user_id: str, product_id: str) -> str:
    """Voeg een product toe aan favorieten, return favorite_id."""
    db = await get_database_service()
    async with db.pool.acquire() as conn:
        # Controleer of product bestaat
        product = await conn.fetchrow(
            "SELECT product_id FROM products WHERE product_id = $1",
            product_id,
        )
        if not product:
            raise ValueError("Product niet gevonden")

        favorite_id = str(uuid.uuid4())
        await conn.execute(
            """
            INSERT INTO user_favorites (favorite_id, user_id, product_id)
            VALUES ($1, $2, $3)
            ON CONFLICT (user_id, product_id) DO NOTHING
            """,
            favorite_id, user_id, product_id,
        )
        return favorite_id


async def remove_favorite(user_id: str, product_id: str) -> None:
    """Verwijder een product uit favorieten."""
    db = await get_database_service()
    async with db.pool.acquire() as conn:
        result = await conn.execute(
            """
            DELETE FROM user_favorites
            WHERE user_id = $1 AND product_id = $2
            """,
            user_id, product_id,
        )
        if result == "DELETE 0":
            raise ValueError("Favoriet niet gevonden")


async def check_favorite(user_id: str, product_id: str) -> bool:
    """Controleer of een product in favorieten staat."""
    db = await get_database_service()
    async with db.pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT 1 FROM user_favorites
            WHERE user_id = $1 AND product_id = $2
            """,
            user_id, product_id,
        )
        return row is not None