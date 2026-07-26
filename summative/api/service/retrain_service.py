from pathlib import Path
from threading import Lock
from typing import Dict

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score, root_mean_squared_error
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

from service.model_service import DATA_DIR, FEATURE_COLUMNS, MODEL_PATH, SCALER_PATH
from service import model_service

TARGET_COLUMN = "cce"
RANDOM_STATE = 42
N_ESTIMATORS = 200

TRAIN_DATA_PATH = DATA_DIR / "wgi_corruption_train_data.csv"
TEST_DATA_PATH = DATA_DIR / "wgi_corruption_test_data.csv"

REQUIRED_COLUMNS = FEATURE_COLUMNS + [TARGET_COLUMN]

_jobs_lock = Lock()
JOBS: Dict[str, dict] = {}


class InvalidRetrainDataError(ValueError):
    pass


def validate_columns(df: pd.DataFrame) -> None:
    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise InvalidRetrainDataError(f"Uploaded CSV is missing required columns: {missing}")


def _set_status(job_id: str, **fields) -> None:
    with _jobs_lock:
        JOBS[job_id].update(fields)


def run_retrain_job(job_id: str, new_data_path: Path) -> None:
    _set_status(job_id, status="running", detail="Loading and merging data")
    try:
        existing = pd.concat(
            [pd.read_csv(TRAIN_DATA_PATH), pd.read_csv(TEST_DATA_PATH)],
            ignore_index=True,
        )[REQUIRED_COLUMNS]
        new_data = pd.read_csv(new_data_path)[REQUIRED_COLUMNS]
        combined = pd.concat([existing, new_data], ignore_index=True).dropna()

        train_df, test_df = train_test_split(combined, test_size=0.2, random_state=RANDOM_STATE)

        scaler = StandardScaler()
        X_train = pd.DataFrame(scaler.fit_transform(train_df[FEATURE_COLUMNS]), columns=FEATURE_COLUMNS)
        X_test = pd.DataFrame(scaler.transform(test_df[FEATURE_COLUMNS]), columns=FEATURE_COLUMNS)
        y_train, y_test = train_df[TARGET_COLUMN], test_df[TARGET_COLUMN]

        _set_status(job_id, detail="Training Random Forest Regressor")
        model = RandomForestRegressor(n_estimators=N_ESTIMATORS, random_state=RANDOM_STATE)
        model.fit(X_train, y_train)

        train_pred, test_pred = model.predict(X_train), model.predict(X_test)
        metrics = {
            "train_rmse": float(root_mean_squared_error(y_train, train_pred)),
            "test_rmse": float(root_mean_squared_error(y_test, test_pred)),
            "train_r2": float(r2_score(y_train, train_pred)),
            "test_r2": float(r2_score(y_test, test_pred)),
            "n_rows_used": int(len(combined)),
        }

        _set_status(job_id, detail="Saving new model artifacts")
        _atomic_dump(model, MODEL_PATH)
        _atomic_dump(scaler, SCALER_PATH)
        model_service.reload()

        _set_status(job_id, status="completed", detail="Retraining finished successfully", metrics=metrics)
    except Exception as exc:
        _set_status(job_id, status="failed", detail=f"Retraining failed: {exc}")


def _atomic_dump(obj, path: Path) -> None:
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    joblib.dump(obj, tmp_path)
    tmp_path.replace(path)
