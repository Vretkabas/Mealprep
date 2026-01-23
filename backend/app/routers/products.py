from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List

# create router
router = APIRouter()

# define product schema (validation)
class ProductSchema(BaseModel):
    name: str
    price: str
    promotion_from: str
    promotion_to: str
    url: str

# endpoint for scraping Delhaize products
@router.post("/products/batch-upload-delhaize")
def upload_delhaize_products(products: List[ProductSchema]):
    try:
        print(f"Ontvangen: {len(products)} producten van Delhaize")
        
        # TODO: loop through products and save to database
        # TODO: Check if product already exists based on URL (check date too)
        # TODO: If exists, update price and promotion dates or remove if same
        
        return {"status": "success", "count": len(products)}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))