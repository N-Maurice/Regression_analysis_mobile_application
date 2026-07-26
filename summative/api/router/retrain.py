import io
import uuid
from pathlib import Path

import pandas as pd
from fastapi import APIRouter, BackgroundTasks, File, HTTPException, UploadFile

from schema.retrain import RetrainAcceptedResponse, RetrainStatusResponse
from service import retrain_service
from service.retrain_service import InvalidRetrainDataError

router = APIRouter(prefix="/retrain", tags=["Retraining"])

INCOMING_DATA_DIR = Path(__file__).resolve().parents[1] / "data" / "incoming"
INCOMING_DATA_DIR.mkdir(parents=True, exist_ok=True)


@router.post("", response_model=RetrainAcceptedResponse, status_code=202)
async def trigger_retrain(background_tasks: BackgroundTasks, file: UploadFile = File(...)) -> RetrainAcceptedResponse:
    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only .csv uploads are supported")

    raw_bytes = await file.read()
    try:
        new_data = pd.read_csv(io.BytesIO(raw_bytes))
        retrain_service.validate_columns(new_data)
    except (InvalidRetrainDataError, ValueError, pd.errors.ParserError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    job_id = uuid.uuid4().hex
    saved_path = INCOMING_DATA_DIR / f"{job_id}.csv"
    saved_path.write_bytes(raw_bytes)

    retrain_service.JOBS[job_id] = {"status": "queued", "detail": "Retraining job queued", "metrics": None}
    background_tasks.add_task(retrain_service.run_retrain_job, job_id, saved_path)

    return RetrainAcceptedResponse(job_id=job_id, status="queued", message="Retraining scheduled in the background")


@router.get("/{job_id}", response_model=RetrainStatusResponse)
def get_retrain_status(job_id: str) -> RetrainStatusResponse:
    job = retrain_service.JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id")
    return RetrainStatusResponse(job_id=job_id, **job)
