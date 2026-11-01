from fastapi import FastAPI

app = FastAPI(
    title="Smart Packaged Product Scanner API",
    version="1.0.0",
    description="Backend services for barcode resolution, Gemini 2.5 Flash vision extraction, and citation RAG"
)

@app.get("/health")
def health_check():
    # ponytail: minimal health probe, expand when database ping is wired
    return {"status": "ok", "version": "1.0.0", "phase": 1}
