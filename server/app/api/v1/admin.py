"""Non-production admin helpers (catalog reseed, etc.)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.session import get_db_session
from app.services.seed_catalog import reseed_official_catalog

router = APIRouter(tags=["admin"])


@router.post("/admin/reseed-catalog", summary="Upsert official scenes/tracks/presets (non-production)")
async def reseed_catalog(
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, object]:
    settings = get_settings()
    if settings.is_production:
        raise HTTPException(status_code=403, detail="Catalog reseed is disabled in production")

    stats = await reseed_official_catalog(session)
    return {"status": "ok", **stats}
