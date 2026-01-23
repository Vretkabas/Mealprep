from fastapi import FastAPI
import asyncpg
import os
from .routers import products # import products router (scraper endpoint)

app = FastAPI()

# include products router
app.include_router(products.router)

# get database url
DATABASE_URL = os.getenv("DATABASE_URL")

@app.get("/")
def root():
    return {"message": "Mealprep API is running!"}