from fastapi import APIRouter, HTTPException, Depends
from app.auth import get_current_user
from fastapi.responses import Response
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import uuid
import requests as http_requests
from app.services.product_service import find_product_by_name, find_product_by_barcode, get_db_stats
from app.services.database_service import get_database_service
from app.services.gemini_service import enrich_products_batched

router = APIRouter()


# ==================== HELPER FUNCTIONS ====================

def parse_deal_info(discount: str) -> tuple:
    """
    Fallback: parse discount string to (is_meerdere_artikels, deal_quantity).
    Used when Gemini doesn't return these fields.
      "N+M GRATIS"          -> (True,  N+M)   bv. "6+6 GRATIS" -> (True, 12)
      "2de/2e GRATIS"       -> (True,  2)
      "2de aan -X%"         -> (True,  2)
      "2de aan halve prijs" -> (True,  2)
      "-20%", "30% KORTING" -> (False, 1)
    """
    import re
    try:
        d = discount.strip().upper()

        match_nm = re.search(r'(\d+)\+(\d+)\s*GRATIS', d)
        if match_nm:
            n, m = int(match_nm.group(1)), int(match_nm.group(2))
            return True, n + m

        if re.search(r'2(?:DE|E)\s+GRATIS', d):
            return True, 2

        if re.search(r'2(?:DE|E)\s+AAN\s+', d):
            return True, 2

        # "-40% VANAF 6 ST" / "40% VANAF 6 ST"
        match_vanaf = re.search(r'VANAF\s+(\d+)\s*ST', d)
        if match_vanaf:
            return True, int(match_vanaf.group(1))

        return False, 1
    except Exception:
        return False, 1


def parse_discount_percentage(discount: str) -> Optional[float]:
    """
    Parse discount string to percentage.
    Supports many Colruyt promotion formats:
      "-50%" -> 50.0
      "1+1 GRATIS" -> 50.0
      "2+1 GRATIS" -> 33.33
      "2de aan -50%" -> 25.0 (half the discount applied to total)
      "2de aan halve prijs" -> 25.0
      "2e gratis" / "2de gratis" -> 50.0
      "3+2 GRATIS" -> 40.0
    """
    import re
    try:
        import re
        discount = discount.strip().upper()

        # Handle "2de aan -50%" / "2de aan 50%" -> half discount on total
        match_2de_pct = re.search(r'2(?:DE|E)\s+AAN\s+[- ]?(\d+(?:[.,]\d+)?)\s*%', discount)
        if match_2de_pct:
            pct_on_second = float(match_2de_pct.group(1).replace(",", "."))
            # Discount applies to second item only → total discount is half
            return round(pct_on_second / 2, 2)

        # Handle "2de aan halve prijs" / "2e aan halve prijs" -> 25% total
        if re.search(r'2(?:DE|E)\s+AAN\s+HALVE\s+PRIJS', discount):
            return 25.0

        # Handle "2e gratis" / "2de gratis" -> same as 1+1
        if re.search(r'2(?:DE|E)\s+GRATIS', discount):
            return 50.0

        # Handle generic N+M GRATIS pattern: "1+1", "2+1", "3+1", "3+2", etc.
        match_nm = re.search(r'(\d+)\+(\d+)\s*GRATIS', discount)
        if match_nm:
            n = int(match_nm.group(1))
            m = int(match_nm.group(2))
            # You buy N+M but only pay for N → discount = M/(N+M) * 100
            return round(m / (n + m) * 100, 2)

        # Handle simple percentage format: "-50%", "50%", "-25%", "-40% VANAF 6 ST"
        match_pct = re.search(r'(\d+(?:[.,]\d+)?)\s*%', discount)
        if match_pct:
            return float(match_pct.group(1).replace(",", "."))

        return None
    except:
        return None


def parse_date(date_str: str) -> datetime:
    """
    Parse date string to datetime.
    Expected formats: "29/1", "29/1/2025", "29-1-2025"
    """
    try:
        # Try different formats
        for fmt in ["%d/%m/%Y", "%d/%m", "%d-%m-%Y", "%d-%m"]:
            try:
                dt = datetime.strptime(date_str, fmt)
                # If no year specified, use current year
                if dt.year == 1900:
                    dt = dt.replace(year=datetime.now().year)
                return dt
            except ValueError:
                continue
        # Default to today if parsing fails
        return datetime.now()
    except:
        return datetime.now()


# ==================== SCHEMAS ====================

class AddToCartRequest(BaseModel):
    list_id: str
    product_id: str
    quantity: int = 1
    has_promo: bool = False
    promo_id: Optional[str] = None
    price_per_unit: Optional[float] = None

# Schema for macros from scraper
class MacrosSchema(BaseModel):
    energy_kj: Optional[float] = None
    energy_kcal: Optional[float] = None
    fat: Optional[float] = None
    saturated_fat: Optional[float] = None
    carbohydrates: Optional[float] = None
    sugars: Optional[float] = None
    proteins: Optional[float] = None
    salt: Optional[float] = None


# Schema for incoming Delhaize products from scraper
class ProductSchema(BaseModel):
    name: str
    price: str
    promotion_from: str
    promotion_to: str
    url: str
    macros: Optional[MacrosSchema] = None


# Schema for processed product result
class ProcessedProduct(BaseModel):
    name: str
    barcode: Optional[str]
    brands: Optional[str]
    energy_kcal_100g: Optional[float]
    proteins_100g: Optional[float]
    carbohydrates_100g: Optional[float]
    fat_100g: Optional[float]
    match_score: Optional[float]
    match_status: str
    delhaize_url: str
    delhaize_id: str


# Schema for incoming Colruyt products from scraper
class ColruytProductSchema(BaseModel):
    url: str
    name: Optional[str] = None  # Product name scraped from Colruyt page <h1>
    discount: str
    barcode: str
    price: Optional[float] = None


# Schema for Colruyt batch upload with promotion dates
class ColruytBatchUpload(BaseModel):
    products: List[ColruytProductSchema]
    promotion_from: Optional[str] = None  # e.g. "29/1"
    promotion_to: Optional[str] = None    # e.g. "4/2"


# Schema for processed Colruyt product result
class ProcessedColruytProduct(BaseModel):
    barcode: str
    product_name: Optional[str]
    brands: Optional[str]
    discount: str
    energy_kcal_100g: Optional[float]
    proteins_100g: Optional[float]
    carbohydrates_100g: Optional[float]
    fat_100g: Optional[float]
    sugars_100g: Optional[float]
    fiber_100g: Optional[float]
    salt_100g: Optional[float]
    match_status: str
    colruyt_url: str
    saved_to_db: bool = False


# ==================== HELPER FUNCTIONS ====================

def extract_delhaize_id(url: str) -> str:
    """Extract the internal Delhaize product ID from the URL."""
    return url.rstrip('/').split('/')[-1]


# ==================== ENDPOINTS ====================

@router.get("/products")
async def get_products(store: str = None, limit: int = 50):
    """
    Haal producten op uit de Supabase 'products' tabel.
    Je kunt optioneel filteren op een specifieke winkel (bijv. op brand of een store kolom).
    """
    try:
        db = await get_database_service()
        async with db.pool.acquire() as conn:
            # Pas de query aan op basis van hoe je winkels opslaat (bijv. in 'brand' of een aparte store kolom)
            if store:
                 query = "SELECT product_id, product_name, brand, price, content, image_url FROM products WHERE brand ILIKE $1 LIMIT $2"
                 rows = await conn.fetch(query, f"%{store}%", limit)
            else:
                 query = "SELECT product_id, product_name, brand, price, content, image_url FROM products LIMIT $1"
                 rows = await conn.fetch(query, limit)
            
            products = [dict(row) for row in rows]
            return products
    except Exception as e:
        print(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/shopping-list/add")
async def add_to_shopping_list(req: AddToCartRequest, user_id: str = Depends(get_current_user)):
    """
    Voeg een product toe aan een specifieke shopping list (shopping_list_items tabel)
    """
    try:
        db = await get_database_service()
        async with db.pool.acquire() as conn:
            # Controleer of lijst van ingelogde gebruiker is
            owner = await conn.fetchrow(
                "SELECT list_id FROM shopping_lists WHERE list_id = $1::uuid AND user_id = $2::uuid",
                req.list_id, user_id
            )
            if not owner:
                raise HTTPException(status_code=403, detail="Lijst niet gevonden of geen toegang")

            # Check of product al in de lijst zit
            existing = await conn.fetchrow(
                """
                SELECT item_id, quantity FROM shopping_list_items
                WHERE list_id = $1::uuid AND product_id = $2::uuid
                """,
                req.list_id, req.product_id
            )

            if existing:
                # Update quantity (en promo info als meegegeven)
                await conn.execute(
                    """
                    UPDATE shopping_list_items
                    SET quantity = $1,
                        has_promo = COALESCE($3, has_promo),
                        promo_id = COALESCE($4::uuid, promo_id),
                        price_per_unit = COALESCE($5, price_per_unit)
                    WHERE item_id = $2::uuid
                    """,
                    req.quantity, str(existing['item_id']),
                    req.has_promo if req.has_promo else None,
                    req.promo_id,
                    req.price_per_unit
                )
            else:
                # Insert nieuw item
                item_id = str(uuid.uuid4())
                await conn.execute(
                    """
                    INSERT INTO shopping_list_items
                        (item_id, list_id, product_id, quantity, has_promo, promo_id, price_per_unit)
                    VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6::uuid, $7)
                    """,
                    item_id, req.list_id, req.product_id, req.quantity,
                    req.has_promo, req.promo_id, req.price_per_unit
                )
        return {"message": "Product succesvol toegevoegd aan lijst"}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error adding to list: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/products/db-stats")
def database_stats():
    """Get OpenFoodFacts database statistics."""
    return get_db_stats()


@router.post("/products/batch-upload-delhaize")
def upload_delhaize_products(products: List[ProductSchema]):
    """
    Process products from Delhaize scraper.
    """
    try:
        print(f"Received: {len(products)} products from Delhaize")

        results = {
            "matched": [],
            "no_match": [],
            "errors": []
        }

        for product in products:
            try:
                delhaize_id = extract_delhaize_id(product.url)
                matches = find_product_by_name(product.name, limit=1, min_score=70.0)

                if matches and matches[0].match_score >= 70.0:
                    match = matches[0]
                    processed = ProcessedProduct(
                        name=product.name,
                        barcode=match.barcode,
                        brands=match.brands,
                        energy_kcal_100g=match.energy_kcal_100g,
                        proteins_100g=match.proteins_100g,
                        carbohydrates_100g=match.carbohydrates_100g,
                        fat_100g=match.fat_100g,
                        match_score=match.match_score,
                        match_status="matched",
                        delhaize_url=product.url,
                        delhaize_id=delhaize_id
                    )
                    results["matched"].append(processed.model_dump())
                else:
                    scraped_macros = product.macros
                    processed = ProcessedProduct(
                        name=product.name,
                        barcode=None,
                        brands=None,
                        energy_kcal_100g=scraped_macros.energy_kcal if scraped_macros else None,
                        proteins_100g=scraped_macros.proteins if scraped_macros else None,
                        carbohydrates_100g=scraped_macros.carbohydrates if scraped_macros else None,
                        fat_100g=scraped_macros.fat if scraped_macros else None,
                        match_score=matches[0].match_score if matches else 0.0,
                        match_status="no_match",
                        delhaize_url=product.url,
                        delhaize_id=delhaize_id
                    )
                    results["no_match"].append(processed.model_dump())

            except Exception as e:
                results["errors"].append({
                    "product": product.name,
                    "error": str(e)
                })

        return {
            "status": "success",
            "total": len(products),
            "matched": len(results["matched"]),
            "no_match": len(results["no_match"]),
            "errors": len(results["errors"]),
            "results": results
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== COLRUYT SCRAPER ENDPOINTS ====================

@router.post("/products/batch-upload-colruyt")
async def upload_colruyt_products(batch: ColruytBatchUpload):
    """
    Process products from Colruyt scraper and save to database.

    Flow:
    1. Get or create Colruyt store in database
    2. Group products by URL (same product may have multiple barcodes)
    3. For each URL, try barcodes until one matches in OpenFoodFacts
    4. Batch all product names → send to Gemini for AI enrichment (category, macro, healthy)
    5. Save product to database (upsert)
    6. Create promotion record with discount + Gemini enrichment
    """
    try:
        products = batch.products
        print(f"Received: {len(products)} products from Colruyt")

        # Parse promotion dates
        valid_from = parse_date(batch.promotion_from) if batch.promotion_from else datetime.now()
        valid_until = parse_date(batch.promotion_to) if batch.promotion_to else datetime.now()

        # Get database service
        db = await get_database_service()

        # Get or create Colruyt store
        store_id = await db.get_or_create_store(
            store_name="Colruyt",
            logo_url="https://www.colruyt.be/favicon.ico"
        )

        # Deactivate old promotions for Colruyt
        deactivated = await db.deactivate_old_promotions(store_id)
        print(f"Deactivated {deactivated} old promotions")

        # Group products by URL (same product may have multiple barcodes to try)
        products_by_url = {}
        for product in products:
            if product.url not in products_by_url:
                products_by_url[product.url] = {
                    "url": product.url,
                    "scraped_name": product.name,  # Name from Colruyt <h1>
                    "discount": product.discount,
                    "price": product.price,
                    "barcodes": []
                }
            products_by_url[product.url]["barcodes"].append(product.barcode)

        print(f"Grouped into {len(products_by_url)} unique products")

        # ====================================================
        # PHASE 1: Match all barcodes against OpenFoodFacts
        # ====================================================
        url_list = list(products_by_url.keys())
        matched_data = {}  # url -> {match, barcode, product_name, ...}

        for url in url_list:
            product_info = products_by_url[url]
            barcodes = product_info["barcodes"]

            match = None
            matched_barcode = None
            for barcode in barcodes:
                match = find_product_by_barcode(barcode)
                if match:
                    matched_barcode = barcode
                    print(f"  Found match for barcode {barcode}")
                    break
                else:
                    print(f"  No match for barcode {barcode}")

            # Name priority: scraped from Colruyt > OpenFoodFacts > fallback
            scraped_name = product_info.get("scraped_name")
            off_name = match.product_name if match else None
            best_name = scraped_name or off_name or f"Unknown Product ({barcodes[0]})"

            matched_data[url] = {
                "match": match,
                "barcode": matched_barcode or barcodes[0],
                "product_name": best_name,
                "is_matched": match is not None,
            }

        # ====================================================
        # PHASE 2: Send all product names to Gemini for AI enrichment
        # ====================================================
        # Always send the best available name (scraped from Colruyt page)
        product_names = [matched_data[url]["product_name"] for url in url_list]
        product_discounts = [products_by_url[url]["discount"] for url in url_list]
        product_prices = [products_by_url[url].get("price") for url in url_list]
        print(f"\nSending {len(product_names)} products to Gemini for enrichment...")
        enrichments = await enrich_products_batched(product_names, product_discounts, product_prices)
        print(f"Gemini enrichment complete: {len(enrichments)} results")

        # Map enrichments back to URLs
        enrichment_by_url = {}
        for i, url in enumerate(url_list):
            enrichment_by_url[url] = enrichments[i] if i < len(enrichments) else {
                "clean_name": None, "category": "Overig", "primary_macro": "None", "is_healthy": False
            }

        # ====================================================
        # PHASE 3: Save everything to database
        # ====================================================
        results = {
            "matched": [],
            "not_found": [],
            "errors": []
        }

        for url in url_list:
            try:
                product_info = products_by_url[url]
                match_info = matched_data[url]
                enrichment = enrichment_by_url[url]

                discount = product_info["discount"]
                original_price = product_info.get("price")

                # Promo price: prefer Gemini's calculation (handles complex deals like 2+1 GRATIS)
                # Fall back to simple percentage math if Gemini returned null
                gemini_promo_price = enrichment.get("promo_price")
                if gemini_promo_price is not None:
                    try:
                        promo_price = round(float(gemini_promo_price), 2)
                    except (ValueError, TypeError):
                        promo_price = None
                else:
                    discount_pct = parse_discount_percentage(discount)
                    promo_price = None
                    if original_price and discount_pct:
                        promo_price = round(original_price * (1 - discount_pct / 100), 2)

                # Multi-artikel info: prefer Gemini, fallback to regex parser
                gemini_meerdere = enrichment.get("is_meerdere_artikels")
                gemini_deal_qty = enrichment.get("deal_quantity")
                if gemini_meerdere is not None and gemini_deal_qty is not None:
                    is_meerdere_artikels = bool(gemini_meerdere)
                    deal_quantity = int(gemini_deal_qty)
                else:
                    is_meerdere_artikels, deal_quantity = parse_deal_info(discount)

                # Gemini enrichment data
                category = enrichment.get("category", "Overig")
                primary_macro = enrichment.get("primary_macro", "None")
                is_healthy = enrichment.get("is_healthy", False)
                clean_name = enrichment.get("clean_name")

                match = match_info["match"]
                barcode = match_info["barcode"]
                product_name = match_info["product_name"]

                # Name priority: Gemini clean_name > scraped Colruyt name > OpenFoodFacts > fallback
                display_name = clean_name or product_name or "Unknown"

                if match_info["is_matched"]:
                    # Product found in OpenFoodFacts - save with full nutrition data
                    product_id = await db.upsert_product(
                        barcode=barcode,
                        product_name=display_name,
                        brand=match.brands,
                        energy_kcal=match.energy_kcal_100g,
                        proteins_g=match.proteins_100g,
                        carbohydrates_g=match.carbohydrates_100g,
                        sugars_g=match.sugars_100g,
                        fat_g=match.fat_100g
                    )

                    await db.create_promotion(
                        store_id=store_id,
                        product_id=product_id,
                        barcode=barcode,
                        product_name=display_name,
                        discount_label=discount,
                        valid_from=valid_from.date(),
                        valid_until=valid_until.date(),
                        original_price=original_price,
                        promo_price=promo_price,
                        category=category,
                        primary_macro=primary_macro,
                        is_healthy=is_healthy,
                        is_meerdere_artikels=is_meerdere_artikels,
                        deal_quantity=deal_quantity,
                    )

                    processed = ProcessedColruytProduct(
                        barcode=barcode,
                        product_name=display_name,
                        brands=match.brands,
                        discount=discount,
                        energy_kcal_100g=match.energy_kcal_100g,
                        proteins_100g=match.proteins_100g,
                        carbohydrates_100g=match.carbohydrates_100g,
                        fat_100g=match.fat_100g,
                        sugars_100g=match.sugars_100g,
                        fiber_100g=match.fiber_100g,
                        salt_100g=match.salt_100g,
                        match_status="matched",
                        colruyt_url=url,
                        saved_to_db=True
                    )
                    results["matched"].append(processed.model_dump())

                else:
                    # No barcode matched
                    product_id = await db.upsert_product(
                        barcode=barcode,
                        product_name=display_name
                    )

                    await db.create_promotion(
                        store_id=store_id,
                        product_id=product_id,
                        barcode=barcode,
                        product_name=display_name,
                        discount_label=discount,
                        valid_from=valid_from.date(),
                        valid_until=valid_until.date(),
                        original_price=original_price,
                        promo_price=promo_price,
                        category=category,
                        primary_macro=primary_macro,
                        is_healthy=is_healthy,
                        is_meerdere_artikels=is_meerdere_artikels,
                        deal_quantity=deal_quantity,
                    )

                    processed = ProcessedColruytProduct(
                        barcode=barcode,
                        product_name=display_name,
                        brands=None,
                        discount=discount,
                        energy_kcal_100g=None,
                        proteins_100g=None,
                        carbohydrates_100g=None,
                        fat_100g=None,
                        sugars_100g=None,
                        fiber_100g=None,
                        salt_100g=None,
                        match_status="not_found",
                        colruyt_url=url,
                        saved_to_db=True
                    )
                    results["not_found"].append(processed.model_dump())

            except Exception as e:
                results["errors"].append({
                    "url": url,
                    "barcodes": products_by_url[url]["barcodes"],
                    "error": str(e)
                })

        return {
            "status": "success",
            "store_id": store_id,
            "promotion_period": {
                "from": valid_from.strftime("%Y-%m-%d"),
                "to": valid_until.strftime("%Y-%m-%d")
            },
            "total_entries": len(products),
            "unique_products": len(products_by_url),
            "matched": len(results["matched"]),
            "not_found": len(results["not_found"]),
            "errors": len(results["errors"]),
            "enriched_by_gemini": len(product_names),
            "results": results
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/products/search")
async def search_products(q: str, store_name: Optional[str] = None):
    """Zoek producten op naam, optioneel gefilterd op winkel (colruyt_category)."""
    try:
        db = await get_database_service()
        async with db.pool.acquire() as conn:
            if store_name:
                rows = await conn.fetch(
                    """
                    SELECT p.product_id, p.barcode, p.product_name, p.brand,
                           p.image_url, p.price, p.content, p.colruyt_category,
                           p.energy_kcal, p.proteins_g, p.carbohydrates_g, p.fat_g
                    FROM products p
                    WHERE LOWER(p.product_name) LIKE LOWER($1)
                      AND p.colruyt_category <> 'Niet-voeding'
                      AND p.price <> 0.00
                    ORDER BY p.product_name
                    LIMIT 500
                    """,
                    f"%{q}%"
                )
            else:
                rows = await conn.fetch(
                    """
                    SELECT product_id, barcode, product_name, brand,
                           image_url, price, content, colruyt_category,
                           energy_kcal, proteins_g, carbohydrates_g, fat_g
                    FROM products
                    WHERE LOWER(product_name) LIKE LOWER($1)
                        AND colruyt_category NOT LIKE 'Niet-voeding'
                    ORDER BY product_name
                    LIMIT 500
                    """,
                    f"%{q}%"
                )
        return {
            "status": "success",
            "total": len(rows),
            "products": [dict(r) for r in rows],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/products/promotions")
async def get_promotions(store_name: Optional[str] = None):
    """Get active promotions, optionally filtered by store name."""
    try:
        db = await get_database_service()

        store_id = None
        if store_name:
            store = await db.get_store_by_name(store_name)
            if store:
                store_id = store["store_id"]

        promotions = await db.get_active_promotions(store_id)

        return {
            "status": "success",
            "total": len(promotions),
            "promotions": promotions
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


ALLOWED_IMAGE_DOMAINS = [
    "static.colruytgroup.com",
    "images.openfoodfacts.org",
    "world.openfoodfacts.org",
    "static.openfoodfacts.org",
]

@router.get("/proxy/image")
def proxy_image(url: str):
    """Proxy product images to avoid CORS issues with external image hosts."""
    if not any(domain in url for domain in ALLOWED_IMAGE_DOMAINS):
        raise HTTPException(status_code=400, detail="Image domain not allowed")
    try:
        headers = {"User-Agent": "Mozilla/5.0"}
        if "colruytgroup.com" in url:
            headers["Referer"] = "https://www.colruyt.be/"
        resp = http_requests.get(url, headers=headers, timeout=10)
        resp.raise_for_status()
        content_type = resp.headers.get("content-type", "image/jpeg")
        return Response(content=resp.content, media_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Could not fetch image: {e}")