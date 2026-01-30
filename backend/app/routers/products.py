from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.services.product_service import find_product_by_name, find_product_by_barcode, get_db_stats
from app.services.database_service import get_database_service

router = APIRouter()


# ==================== HELPER FUNCTIONS ====================

def parse_discount_percentage(discount: str) -> Optional[float]:
    """
    Parse discount string to percentage.
    Examples: "-50%" -> 50.0, "1+1 GRATIS" -> 50.0, "2+1 GRATIS" -> 33.33
    """
    try:
        discount = discount.strip().upper()

        # Handle percentage format: "-50%", "50%", "-25%"
        if "%" in discount:
            num = discount.replace("%", "").replace("-", "").strip()
            return float(num)

        # Handle "1+1 GRATIS" format (50% off)
        if "1+1" in discount:
            return 50.0

        # Handle "2+1 GRATIS" format (33.33% off)
        if "2+1" in discount:
            return 33.33

        # Handle "3+1 GRATIS" format (25% off)
        if "3+1" in discount:
            return 25.0

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
    discount: str
    barcode: str


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
    discount_percentage: Optional[float]
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
    4. Save product to database (upsert)
    5. Create promotion record with discount
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
                    "discount": product.discount,
                    "barcodes": []
                }
            products_by_url[product.url]["barcodes"].append(product.barcode)

        print(f"Grouped into {len(products_by_url)} unique products")

        results = {
            "matched": [],
            "not_found": [],
            "errors": []
        }

        for url, product_info in products_by_url.items():
            try:
                barcodes = product_info["barcodes"]
                discount = product_info["discount"]

                # Parse discount percentage
                discount_pct = parse_discount_percentage(discount)

                # Try each barcode until we find a match in OpenFoodFacts
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

                if match and matched_barcode:
                    # Product found in OpenFoodFacts - save with full nutrition data
                    product_id = await db.upsert_product(
                        barcode=matched_barcode,
                        product_name=match.product_name or "Unknown",
                        brand=match.brands,
                        energy_kcal=match.energy_kcal_100g,
                        proteins_g=match.proteins_100g,
                        carbohydrates_g=match.carbohydrates_100g,
                        sugars_g=match.sugars_100g,
                        fat_g=match.fat_100g
                    )

                    # Create promotion
                    await db.create_promotion(
                        store_id=store_id,
                        product_id=product_id,
                        barcode=matched_barcode,
                        product_name=match.product_name or "Unknown",
                        discount_percentage=discount_pct,
                        valid_from=valid_from.date(),
                        valid_until=valid_until.date()
                    )

                    processed = ProcessedColruytProduct(
                        barcode=matched_barcode,
                        product_name=match.product_name,
                        brands=match.brands,
                        discount=discount,
                        discount_percentage=discount_pct,
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
                    # No barcode matched - use first barcode and save with barcode only
                    first_barcode = barcodes[0]
                    product_id = await db.upsert_product(
                        barcode=first_barcode,
                        product_name=f"Unknown Product ({first_barcode})"
                    )

                    # Create promotion anyway
                    await db.create_promotion(
                        store_id=store_id,
                        product_id=product_id,
                        barcode=first_barcode,
                        product_name=f"Unknown Product ({first_barcode})",
                        discount_percentage=discount_pct,
                        valid_from=valid_from.date(),
                        valid_until=valid_until.date()
                    )

                    processed = ProcessedColruytProduct(
                        barcode=first_barcode,
                        product_name=None,
                        brands=None,
                        discount=discount,
                        discount_percentage=discount_pct,
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
                    "barcodes": product_info["barcodes"],
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
            "results": results
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
