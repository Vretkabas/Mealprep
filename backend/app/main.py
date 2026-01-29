from fastapi import FastAPI
import asyncpg
import os
from .routers import products # import products router (scraper endpoint)
from fastapi.middleware.cors import CORSMiddleware
from app.api.barcode_api import router as barcode_router

app = FastAPI(title="MealPrep API")

# include products router
app.include_router(products.router)

app.include_router(barcode_router)

# get database url
DATABASE_URL = os.getenv("DATABASE_URL")

@app.get("/")
def root():
    return {"message": "Mealprep API is running!"}
  

