from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.barcode_api import router as barcode_router

app = FastAPI(title="MealPrep API")

app.include_router(barcode_router)
