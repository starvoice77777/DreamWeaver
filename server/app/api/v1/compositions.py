from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser
from app.schemas.content import CompositionValidateIn, CompositionValidateOut
from app.services.composition import CompositionValidationError, validate_composition

router = APIRouter(tags=["compositions"])


@router.post(
    "/compositions/validate",
    response_model=CompositionValidateOut,
    summary="Validate a scene_composition_v1 document without persisting",
)
async def validate_composition_endpoint(
    body: CompositionValidateIn,
    user: CurrentUser,
) -> CompositionValidateOut:
    _ = user
    try:
        normalized = validate_composition(body.composition)
    except CompositionValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=exc.as_detail(),
        ) from exc
    return CompositionValidateOut(composition=normalized)
