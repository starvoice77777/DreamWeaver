from fastapi import APIRouter

router = APIRouter()


@router.get("/", summary="Describe the active API version")
async def api_version() -> dict[str, str]:
    return {"name": "DreamWeaver API", "version": "v1"}

