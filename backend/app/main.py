from fastapi import FastAPI
import asyncpg
import os
from .routers import products # import products router (scraper endpoint)
from .routers import user # import user router (preferences endpoint)
from .routers import shopping_lists # import shopping lists router
from .routers import barcode_api # import barcode API router
from .routers import suggestions # import suggestions router
from fastapi.middleware.cors import CORSMiddleware
from app.routers.barcode_api import router as barcode_router
from .routers import suggestions
from app.routers import shopping_lists
from app.routers import favorites_router

app = FastAPI(title="MealPrep API")

# include routers
app.include_router(products.router)
app.include_router(shopping_lists.router)
app.include_router(barcode_api.router)
app.include_router(user.router)
app.include_router(suggestions.router)
app.include_router(favorites_router.router)

# get database url
DATABASE_URL = os.getenv("DATABASE_URL")

@app.get("/")
def root():
    return {"message": "Mealprep API is running!"}
  

