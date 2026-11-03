# testing/unit/phase1/test_phase1_gate.py
from pathlib import Path
from fastapi.testclient import TestClient

def test_phase_1_full_toolchain_gate():
    workspace = Path(__file__).resolve().parents[3]
    
    # 1. Monorepo core directories
    for d in ["data_pipeline", "backend", "mobile_app", "testing"]:
        assert (workspace / d).is_dir(), f"Missing core dir: {d}"
        
    # 2. Backend health endpoint contract
    from backend.main import app
    client = TestClient(app)
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["phase"] == 1
    assert res.json()["status"] == "ok"
    
    # 3. Mobile pubspec integrity and dependencies
    pubspec = (workspace / "mobile_app" / "pubspec.yaml").read_text(encoding="utf-8")
    assert "sqlite3_flutter_libs" in pubspec
    assert "mobile_scanner" in pubspec
    assert "google_mlkit_text_recognition" in pubspec
    assert "flutter_riverpod" in pubspec
    assert "go_router" in pubspec
    
    # 4. Strict testing isolation (zero source test pollution, ignoring .venv)
    backend_tests = [
        p for p in (workspace / "backend").rglob("test_*.py")
        if ".venv" not in p.parts
    ]
    assert len(backend_tests) == 0, f"Source test pollution in backend: {backend_tests}"
    
    mobile_tests = [
        p for p in (workspace / "mobile_app").rglob("test_*.py")
        if ".dart_tool" not in p.parts
    ]
    assert len(mobile_tests) == 0, f"Source test pollution in mobile_app: {mobile_tests}"
