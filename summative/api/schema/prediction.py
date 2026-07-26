from pydantic import BaseModel, Field

_ESTIMATE_BOUNDS = {"ge": -3.5, "le": 3.5}
_STD_ERROR_BOUNDS = {"ge": 0.0, "le": 1.5}


class CorruptionPredictionRequest(BaseModel):
    vae: float = Field(..., **_ESTIMATE_BOUNDS, description="Voice and Accountability - Estimate")
    vas: float = Field(..., **_STD_ERROR_BOUNDS, description="Voice and Accountability - Standard Error")
    pve: float = Field(
        ..., **_ESTIMATE_BOUNDS,
        description="Political Stability and Absence of Violence/Terrorism - Estimate",
    )
    pvs: float = Field(..., **_STD_ERROR_BOUNDS, description="Political Stability - Standard Error")
    gee: float = Field(..., **_ESTIMATE_BOUNDS, description="Government Effectiveness - Estimate")
    ges: float = Field(..., **_STD_ERROR_BOUNDS, description="Government Effectiveness - Standard Error")
    rqe: float = Field(..., **_ESTIMATE_BOUNDS, description="Regulatory Quality - Estimate")
    rqs: float = Field(..., **_STD_ERROR_BOUNDS, description="Regulatory Quality - Standard Error")
    rle: float = Field(..., **_ESTIMATE_BOUNDS, description="Rule of Law - Estimate")
    rls: float = Field(..., **_STD_ERROR_BOUNDS, description="Rule of Law - Standard Error")

    model_config = {
        "json_schema_extra": {
            "example": {
                "vae": 0.85,
                "vas": 0.11,
                "pve": 0.42,
                "pvs": 0.19,
                "gee": 0.77,
                "ges": 0.12,
                "rqe": 0.69,
                "rqs": 0.13,
                "rle": 0.71,
                "rls": 0.14,
            }
        }
    }


class CorruptionPredictionResponse(BaseModel):
    control_of_corruption: float = Field(..., description="Predicted 'cce' - Control of Corruption estimate")
    model_name: str = Field(..., description="Name of the model that produced the prediction")
