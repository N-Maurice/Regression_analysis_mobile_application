import sys
from pathlib import Path

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

"""
ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]
"""

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],#ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
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
