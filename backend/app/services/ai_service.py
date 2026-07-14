from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[3]
AI_MODEL_DIR = PROJECT_ROOT / "ai-model"


def prepare_ai_imports() -> None:
    ai_model_path = str(AI_MODEL_DIR)

    if ai_model_path not in sys.path:
        sys.path.append(ai_model_path)


def check_ai_model_folder() -> dict:
    return {
        "ai_model_path": str(AI_MODEL_DIR),
        "exists": AI_MODEL_DIR.exists(),
        "files": [
            path.name
            for path in AI_MODEL_DIR.iterdir()
            if path.is_file()
        ] if AI_MODEL_DIR.exists() else [],
    }