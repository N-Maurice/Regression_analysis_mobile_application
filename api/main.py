"""WGI Control-of-Corruption Prediction API.

Serves predictions from the Random Forest model trained in
wgi_corruption_linear_regression.ipynb, plus a background retraining
endpoint. Run with `uvicorn main:app --app-dir api --reload` from the repo
root, or `uvicorn api.main:app --reload` — both are supported.
"""

import sys
from pathlib import Path

# router/schema/service import each other with absolute imports (e.g.
# `from schema.prediction import ...`), which only resolve if api/ itself is
# on sys.path. That's automatic when uvicorn is pointed at "main:app" with
# --app-dir api, but not when it's pointed at "api.main:app" from the repo
# root — so make sure api/ is on sys.path either way.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from router import prediction, retrain

app = FastAPI(
    title="WGI Control-of-Corruption Prediction API",
    description=(
        "Predicts a country's World Bank 'Control of Corruption' governance "
        "estimate (cce) from 10 related WGI indicators, and lets an authorized "
        "client trigger a background model retrain with new labelled data."
    ),
    version="1.0.0",
)

# --- CORS ---------------------------------------------------------------
# This API has no auth/session cookies, so credentials are not needed and are
# explicitly disabled (allow_credentials=False) rather than left ambiguous.
#
# allow_origins is an explicit allow-list rather than "*": the /retrain
# endpoint is a comparatively expensive, state-mutating operation (it
# overwrites the production model), so arbitrary third-party sites should not
# be able to invoke it from a victim's browser. Add the deployed Flutter web
# origin here once it exists; the localhost entries cover local dev of both
# the API's Swagger UI and a locally-served frontend.
ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    # Only the HTTP verbs this API actually exposes (GET for status/health,
    # POST for predict/retrain) — not the wildcard "*".
    allow_methods=["GET", "POST"],
    # Content-Type: JSON/multipart request bodies. Authorization: reserved
    # for adding token auth to /retrain later.
    allow_headers=["Content-Type", "Authorization"],
)

app.include_router(prediction.router)
app.include_router(retrain.router)


@app.get("/", tags=["Health"])
def root() -> dict:
    return {"message": "WGI Control-of-Corruption Prediction API is running. See /docs for the Swagger UI."}


@app.get("/health", tags=["Health"])
def health() -> dict:
    return {"status": "ok"}
