"""Pydantic response models for the retraining endpoints."""

from typing import Literal, Optional

from pydantic import BaseModel, Field

JobStatus = Literal["queued", "running", "completed", "failed"]


class RetrainAcceptedResponse(BaseModel):
    job_id: str = Field(..., description="Identifier used to poll job status via GET /retrain/{job_id}")
    status: JobStatus
    message: str


class RetrainMetrics(BaseModel):
    train_rmse: float
    test_rmse: float
    train_r2: float
    test_r2: float
    n_rows_used: int


class RetrainStatusResponse(BaseModel):
    job_id: str
    status: JobStatus
    detail: str
    metrics: Optional[RetrainMetrics] = None
