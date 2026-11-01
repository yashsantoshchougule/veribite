# testing/unit/phase1/test_native_fallbacks.py
from pathlib import Path

def test_mlkit_static_asset_fallback_directory_exists():
    workspace = Path(__file__).resolve().parents[3]
    mlkit_dir = workspace / "mobile_app" / "android" / "app" / "src" / "main" / "assets" / "mlkit"
    assert mlkit_dir.is_dir(), f"Static ML Kit fallback directory missing: {mlkit_dir}"

def test_camera_stream_contract_defines_unified_pipeline():
    workspace = Path(__file__).resolve().parents[3]
    contract = workspace / "mobile_app" / "lib" / "core" / "contracts" / "camera_stream_contract.dart"
    assert contract.is_file(), "Camera stream contract missing"
    content = contract.read_text(encoding="utf-8")
    assert "UnifiedCameraStreamContract" in content
    assert "onBarcodeDetected" in content
    assert "onTextRecognized" in content

def test_fts5_resilience_contract_defines_fallback_behavior():
    workspace = Path(__file__).resolve().parents[3]
    contract = workspace / "mobile_app" / "lib" / "core" / "database" / "fts5_resilience_contract.dart"
    assert contract.is_file(), "FTS5 resilience contract missing"
    content = contract.read_text(encoding="utf-8")
    assert "FTS5ResilienceContract" in content
    assert "verifyFTS5Available" in content
    assert "initializeWithFallback" in content
