# WGI Control-of-Corruption Prediction API

FastAPI service wrapping the Random Forest model trained in
[`wgi_corruption_linear_regression.ipynb`](wgi_corruption_linear_regression.ipynb) to predict a
country's World Bank **Control of Corruption** estimate (`cce`) from 10 related
[Worldwide Governance Indicators](Corruption%20Indicator%20Data%20of%20180%20Governments/wgidataset_readme.pdf).

## Project structure

```
pyproject.toml       # uv-managed dependencies (project root)
uv.lock
.python-version
requirements.txt     # exported for platforms (e.g. Render) that expect pip
model.pkl, scaler.pkl, *.csv, *.ipynb   # produced by the notebook, read by the API as-is

api/
├── schema/          # Pydantic request/response models (data types + range validation)
│   ├── prediction.py
│   └── retrain.py
├── router/           # FastAPI route handlers (HTTP layer only)
│   ├── prediction.py
│   └── retrain.py
├── service/          # Business logic: model loading, prediction, retraining
│   ├── model_service.py
│   └── retrain_service.py
├── data/incoming/    # Uploaded retrain CSVs are archived here (gitignored)
└── main.py           # FastAPI app, CORS middleware, router registration
```

The model artifacts (`model.pkl`, `scaler.pkl`) and datasets live at the repository root, produced by
the notebook — the API reads them from there rather than duplicating them.

## Setup

With [uv](https://docs.astral.sh/uv/) (recommended), from the repo root:

```bash
uv sync
```

Or with plain pip:

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

## Running locally

From the repo root:

```bash
uv run uvicorn main:app --app-dir api --reload
```

Then open **http://127.0.0.1:8000/docs** for the Swagger UI.

## Endpoints

| Method | Path              | Description                                              |
|--------|-------------------|------------------------------------------------------------|
| GET    | `/health`         | Liveness check                                              |
| POST   | `/predict`        | Predicts `cce` from the 10 WGI features                     |
| POST   | `/retrain`        | Uploads a CSV of new labelled rows, retrains in the background |
| GET    | `/retrain/{job_id}` | Polls the status/metrics of a retraining job               |

### `POST /predict`

Body (all fields required, `float`, range-validated by Pydantic):

| Field | Description | Valid range |
|-------|-------------|-------------|
| `vae` | Voice and Accountability — Estimate | -3.5 to 3.5 |
| `vas` | Voice and Accountability — Standard Error | 0.0 to 1.5 |
| `pve` | Political Stability and Absence of Violence/Terrorism — Estimate | -3.5 to 3.5 |
| `pvs` | Political Stability — Standard Error | 0.0 to 1.5 |
| `gee` | Government Effectiveness — Estimate | -3.5 to 3.5 |
| `ges` | Government Effectiveness — Standard Error | 0.0 to 1.5 |
| `rqe` | Regulatory Quality — Estimate | -3.5 to 3.5 |
| `rqs` | Regulatory Quality — Standard Error | 0.0 to 1.5 |
| `rle` | Rule of Law — Estimate | -3.5 to 3.5 |
| `rls` | Rule of Law — Standard Error | 0.0 to 1.5 |

Ranges come from the actual training data distribution (estimate columns run roughly -2.5..2.5 on
the official WGI scale, -3.31..2.43 in this dataset; standard-error columns are always non-negative,
0.10..1.08 here) widened slightly for headroom. Requests outside these bounds are rejected with a
`422` before ever reaching the model.

Response:

```json
{ "control_of_corruption": 0.4256, "model_name": "Random Forest Regressor" }
```

### `POST /retrain`

Multipart upload, field name `file`, a `.csv` containing the 10 feature columns above plus `cce`
(same schema as `wgi_corruption_train_data.csv`/`wgi_corruption_test_data.csv`). The upload is
validated synchronously (correct columns present); the actual retrain — merge with existing data,
re-split, refit `StandardScaler` + `RandomForestRegressor(n_estimators=200, random_state=42)`,
evaluate, atomically replace `model.pkl`/`scaler.pkl` — runs as a **FastAPI `BackgroundTask`** so the
request returns immediately with a `202` and a `job_id`:

```json
{ "job_id": "62431b8d...", "status": "queued", "message": "Retraining scheduled in the background" }
```

### `GET /retrain/{job_id}`

Poll for progress/result:

```json
{
  "job_id": "62431b8d...",
  "status": "completed",
  "detail": "Retraining finished successfully",
  "metrics": { "train_rmse": 0.078, "test_rmse": 0.196, "train_r2": 0.994, "test_r2": 0.963, "n_rows_used": 4878 }
}
```

`status` is one of `queued`, `running`, `completed`, `failed`. Once `completed`, the live model is
already hot-reloaded — the next `/predict` call uses the retrained artifacts.

## CORS

Configured in `main.py` deliberately, not with a wildcard:

- **`allow_origins`** — an explicit allow-list (localhost dev ports for now; add the deployed
  Flutter web origin once it exists) rather than `"*"`. `/retrain` overwrites the production model,
  so arbitrary third-party sites should not be able to trigger it from a visitor's browser.
- **`allow_credentials=False`** — this API has no cookies/session auth, so credentials are explicitly
  turned off rather than left ambiguous (and per spec, `"*"` origins can't be combined with
  credentials anyway).
- **`allow_methods=["GET", "POST"]`** — only the verbs the API actually exposes.
- **`allow_headers=["Content-Type", "Authorization"]`** — `Content-Type` for JSON/multipart bodies,
  `Authorization` reserved for adding token auth to `/retrain` later.

## Deployment (Render)

Not deployed yet by design. When ready: set the build command to `pip install -r requirements.txt`
and the start command to `uvicorn main:app --app-dir api --host 0.0.0.0 --port $PORT`, run from the
repo root so `model.pkl`/`scaler.pkl` resolve correctly.
