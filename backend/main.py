import os
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Load environment variables from .env file
load_dotenv()

from backend.api.products import router as products_router
from backend.api.vision import router as vision_router
from backend.api.advisor import router as advisor_router
from backend.api.auth import router as auth_router
from backend.core.rate_limiter import RateLimitMiddleware

app = FastAPI(
    title="Smart Packaged Product Scanner API",
    version="1.0.0",
    description="Backend services for barcode resolution, Gemini 2.5 Flash vision extraction, citation RAG, and Supabase auth"
)

# CORS configuration allowing cross-origin calls from Android apps, LAN browsers & proxies
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Enforce multi-tier sliding window rate limiting
app.add_middleware(RateLimitMiddleware)

app.include_router(products_router)
app.include_router(vision_router)
app.include_router(advisor_router)
app.include_router(auth_router)

@app.get("/health")
def health_check():
    """Ultra-fast (<10ms) health probe for mobile network discovery and connection test."""
    return {
        "status": "ok",
        "service": "veribite-vision-proxy",
        "version": "1.0.0",
        "phase": 1,
    }
