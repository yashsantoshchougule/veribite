# testing/unit/phase1/test_native_fallbacks.py
from pathlib import Path

def _get_workspace():
    return next(p for p in Path(__file__).resolve().parents if (p / "mobile_app").is_dir())

def test_mlkit_static_asset_fallback_directory_exists():
    workspace = _get_workspace()
    mlkit_dir = workspace / "mobile_app" / "android" / "app" / "src" / "main" / "assets" / "mlkit"
    assert mlkit_dir.is_dir(), f"Static ML Kit fallback directory missing: {mlkit_dir}"

def test_camera_stream_contract_defines_unified_pipeline():
    workspace = _get_workspace()
    contract = workspace / "mobile_app" / "lib" / "core" / "contracts" / "camera_stream_contract.dart"
    assert contract.is_file(), "Camera stream contract missing"
    content = contract.read_text(encoding="utf-8")
    assert "UnifiedCameraStreamContract" in content
    assert "onBarcodeDetected" in content
    assert "onTextRecognized" in content

def test_fts5_resilience_contract_defines_fallback_behavior():
    workspace = _get_workspace()
    contract = workspace / "mobile_app" / "lib" / "core" / "database" / "fts5_resilience_contract.dart"
    assert contract.is_file(), "FTS5 resilience contract missing"
    content = contract.read_text(encoding="utf-8")
    assert "FTS5ResilienceContract" in content
    assert "verifyFTS5Available" in content
    assert "initializeWithFallback" in content
