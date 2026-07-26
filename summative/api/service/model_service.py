from pathlib import Path
from threading import Lock
from typing import List

import joblib
import pandas as pd

from schema.prediction import CorruptionPredictionRequest

ROOT_DIR = Path(__file__).resolve().parents[2]
MODEL_PATH = ROOT_DIR / "model.pkl"
SCALER_PATH = ROOT_DIR / "scaler.pkl"

FEATURE_COLUMNS: List[str] = ["vae", "vas", "pve", "pvs", "gee", "ges", "rqe", "rqs", "rle", "rls"]

MODEL_NAME = "Random Forest Regressor"

_lock = Lock()
_model = None
_scaler = None

class ModelNotLoadedError(RuntimeError):
    pass


def _load() -> None:
    global _model, _scaler
    if not MODEL_PATH.exists() or not SCALER_PATH.exists():
        raise ModelNotLoadedError(
            f"Model artifacts not found at {MODEL_PATH} / {SCALER_PATH}. "
            "Run the notebook first to produce model.pkl and scaler.pkl."
        )
    _model = joblib.load(MODEL_PATH)
    _scaler = joblib.load(SCALER_PATH)


def get_model_and_scaler():
    with _lock:
        if _model is None or _scaler is None:
            _load()
        return _model, _scaler


def reload() -> None:
    with _lock:
        _load()


def predict(payload: CorruptionPredictionRequest) -> float:
    model, scaler = get_model_and_scaler()
    row = pd.DataFrame([[getattr(payload, col) for col in FEATURE_COLUMNS]], columns=FEATURE_COLUMNS)
    scaled_row = pd.DataFrame(scaler.transform(row), columns=FEATURE_COLUMNS)
    prediction = model.predict(scaled_row)[0]
    return float(prediction)
