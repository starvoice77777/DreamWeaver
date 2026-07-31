from fastapi import APIRouter

from app.api.v1.content import auth_router, users_router
from app.api.v1.content import router as content_router

router = APIRouter()
router.include_router(content_router)
router.include_router(auth_router)
router.include_router(users_router)


@router.get("/", summary="Describe the active API version")
async def api_version() -> dict[str, str]:
    return {"name": "DreamWeaver API", "version": "v1"}
