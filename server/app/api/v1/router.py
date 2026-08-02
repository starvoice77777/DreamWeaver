from fastapi import APIRouter

from app.api.v1.admin import router as admin_router
from app.api.v1.analytics import router as analytics_router
from app.api.v1.content import auth_router, users_router
from app.api.v1.content import router as content_router
from app.api.v1.library import router as library_router
from app.api.v1.seeds import router as seeds_router

router = APIRouter()
router.include_router(content_router)
router.include_router(auth_router)
router.include_router(users_router)
router.include_router(library_router)
router.include_router(seeds_router)
router.include_router(analytics_router)
router.include_router(admin_router)


@router.get("/", summary="Describe the active API version")
async def api_version() -> dict[str, str]:
    return {"name": "DreamWeaver API", "version": "v1"}
