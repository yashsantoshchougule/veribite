from fastapi import FastAPI
from backend.api.products import router as products_router
from backend.api.vision import router as vision_router

app = FastAPI(
    title="Smart Packaged Product Scanner API",
    version="1.0.0",
    description="Backend services for barcode resolution, Gemini 2.5 Flash vision extraction, and citation RAG"
)

app.include_router(products_router)
app.include_router(vision_router)

@app.get("/health")
def health_check():
    # ponytail: minimal health probe, expand when database ping is wired
    return {"status": "ok", "version": "1.0.0", "phase": 1}
