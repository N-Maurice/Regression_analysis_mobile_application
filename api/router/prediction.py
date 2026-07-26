from fastapi import APIRouter, HTTPException

from schema.prediction import CorruptionPredictionRequest, CorruptionPredictionResponse
from service import model_service
from service.model_service import ModelNotLoadedError

router = APIRouter(prefix="/predict", tags=["Prediction"])


@router.post("", response_model=CorruptionPredictionResponse)
def predict_control_of_corruption(payload: CorruptionPredictionRequest) -> CorruptionPredictionResponse:
    """Predicts the WGI 'Control of Corruption' estimate (cce) from the 10 governance features."""
    try:
        prediction = model_service.predict(payload)
    except ModelNotLoadedError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    return CorruptionPredictionResponse(control_of_corruption=prediction, model_name=model_service.MODEL_NAME)
