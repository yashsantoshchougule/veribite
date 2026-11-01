# testing/unit/phase1/test_flutter_pubspec.py
from pathlib import Path
import yaml

def test_flutter_pubspec_contains_all_blueprint_dependencies():
    workspace = Path(__file__).resolve().parents[3]
    pubspec_path = workspace / "mobile_app" / "pubspec.yaml"
    assert pubspec_path.is_file(), "mobile_app/pubspec.yaml not found"
    
    with open(pubspec_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
        
    deps = data.get("dependencies", {})
    required_packages = [
        "flutter",
        "flutter_riverpod",
        "go_router",
        "sqflite",
        "sqlite3_flutter_libs",
        "mobile_scanner",
        "google_mlkit_text_recognition",
        "image",
        "flutter_tts",
        "url_launcher",
        "pdf",
        "printing",
    ]
    for pkg in required_packages:
        assert pkg in deps, f"Required dependency missing from pubspec.yaml: {pkg}"

def test_flutter_main_entry_scaffold_exists():
    workspace = Path(__file__).resolve().parents[3]
    main_dart = workspace / "mobile_app" / "lib" / "main.dart"
    assert main_dart.is_file(), "mobile_app/lib/main.dart not found"
    content = main_dart.read_text(encoding="utf-8")
    assert "ProviderScope" in content
    assert "runApp" in content
