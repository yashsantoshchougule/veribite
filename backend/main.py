import os
from dotenv import load_dotenv
from fastapi import FastAPI

# Load environment variables from .env file
load_dotenv()

from backend.api.products import router as products_router
from backend.api.vision import router as vision_router
from backend.api.advisor import router as advisor_router
from backend.api.auth import router as auth_router

app = FastAPI(
    title="Smart Packaged Product Scanner API",
    version="1.0.0",
    description="Backend services for barcode resolution, Gemini 2.5 Flash vision extraction, citation RAG, and Supabase auth"
)

app.include_router(products_router)
app.include_router(vision_router)
app.include_router(advisor_router)
app.include_router(auth_router)

@app.get("/health")
def health_check():
    # ponytail: minimal health probe, expand when database ping is wired
    return {"status": "ok", "version": "1.0.0", "phase": 1}
