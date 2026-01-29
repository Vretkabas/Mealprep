from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from app.services.product_service import find_product_by_name, get_db_stats

router = APIRouter()


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
    macros: Optional[MacrosSchema] = None  # Scraped nutrition info (fallback if no OFF match)


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
    match_status: str  # "matched", "no_match", "needs_review"
    delhaize_url: str
    delhaize_id: str  # Internal Delhaize ID extracted from URL


def extract_delhaize_id(url: str) -> str:
    """Extract the internal Delhaize product ID from the URL."""
    # URL format: https://www.delhaize.be/nl/shop/product/name-here/S2020012345678900000
    # The ID is the last part of the URL
    return url.rstrip('/').split('/')[-1]


@router.get("/products/db-stats")
def database_stats():
    """Get OpenFoodFacts database statistics."""
    return get_db_stats()


@router.post("/products/batch-upload-delhaize")
def upload_delhaize_products(products: List[ProductSchema]):
    """
    Process products from Delhaize scraper.

    Flow:
    1. Try to match product name with OpenFoodFacts database
    2. If match found: use barcode + macros from OFF
    3. If no match: create product with Delhaize internal ID
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
                # Extract Delhaize internal ID from URL
                delhaize_id = extract_delhaize_id(product.url)

                # Try fuzzy match with OpenFoodFacts
                matches = find_product_by_name(product.name, limit=1, min_score=70.0)

                if matches and matches[0].match_score >= 70.0:
                    # Good match found
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

                    # TODO: Save to Supabase products table
                    # TODO: Save promotion to promotions table

                else:
                    # No good match - use scraped macros from Delhaize as fallback
                    scraped_macros = product.macros
                    processed = ProcessedProduct(
                        name=product.name,
                        barcode=None,  # No barcode known
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

                    # TODO: Save to Supabase with needs_review=True
                    # TODO: Save promotion to promotions table

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