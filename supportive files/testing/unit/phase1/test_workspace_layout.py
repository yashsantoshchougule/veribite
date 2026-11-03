# testing/unit/phase1/test_workspace_layout.py
from pathlib import Path

def test_monorepo_top_level_directories_exist():
    workspace = Path(__file__).resolve().parents[3]
    required_dirs = [
        workspace / "data_pipeline",
        workspace / "backend",
        workspace / "mobile_app",
        workspace / "testing" / "unit" / "phase1",
        workspace / "testing" / "integration",
        workspace / "testing" / "fixtures",
        workspace / "testing" / "scratch",
    ]
    for directory in required_dirs:
        assert directory.is_dir(), f"Required directory missing: {directory}"

def test_gitignore_covers_python_flutter_and_test_artifacts():
    workspace = Path(__file__).resolve().parents[3]
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
