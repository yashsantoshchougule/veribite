# testing/unit/phase1/test_workspace_layout.py
from pathlib import Path

def _get_workspace():
    return next(p for p in Path(__file__).resolve().parents if (p / "mobile_app").is_dir())

def test_monorepo_top_level_directories_exist():
    workspace = _get_workspace()
    testing_base = workspace / "testing" if (workspace / "testing").is_dir() else workspace / "supportive files" / "testing"
    required_dirs = [
        workspace / "data_pipeline",
        workspace / "backend",
        workspace / "mobile_app",
        testing_base / "unit" / "phase1",
        testing_base / "integration",
        testing_base / "fixtures",
        testing_base / "scratch",
    ]
    for directory in required_dirs:
        assert directory.is_dir(), f"Required directory missing: {directory}"

def test_gitignore_covers_python_flutter_and_test_artifacts():
    workspace = _get_workspace()
    gitignore_path = workspace / ".gitignore"
    assert gitignore_path.is_file(), ".gitignore does not exist"
    content = gitignore_path.read_text(encoding="utf-8")
    required_patterns = [
        ".venv",
        "__pycache__",
        "*.pyc",
        ".dart_tool",
        "build/",
        "testing/scratch/*",
        ".env",
    ]
    for pattern in required_patterns:
        assert pattern in content, f"Missing pattern in .gitignore: {pattern}"
