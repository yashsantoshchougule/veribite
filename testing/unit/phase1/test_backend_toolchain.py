# testing/unit/phase1/test_backend_toolchain.py
import pytest
from fastapi.testclient import TestClient

def test_required_backend_modules_importable():
    import fastapi
    import uvicorn
    import pydantic
    import httpx
    assert fastapi.__version__
    assert pydantic.__version__

def test_backend_health_endpoint():
    from backend.main import app
    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data
    assert data["phase"] == 1
