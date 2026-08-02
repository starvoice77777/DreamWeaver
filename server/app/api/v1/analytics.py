from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.schemas.analytics import (
    AnalyticsEventsAcceptedOut,
    AnalyticsEventsBatchIn,
    UsageSummaryOut,
)
from app.services import analytics as analytics_service

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.post(
    "/events",
    response_model=AnalyticsEventsAcceptedOut,
    summary="Batch ingest companionship analytics events",
)
async def post_events(
    body: AnalyticsEventsBatchIn,
    session: DbSession,
    user: CurrentUser,
) -> AnalyticsEventsAcceptedOut:
    accepted, skipped = await analytics_service.ingest_events(session, user, body.events)
    return AnalyticsEventsAcceptedOut(accepted=accepted, skipped_duplicates=skipped)


@router.get(
    "/summary",
    response_model=UsageSummaryOut,
    summary="Companionship usage summary for the current user",
)
async def get_summary(session: DbSession, user: CurrentUser) -> UsageSummaryOut:
    row = await analytics_service.get_or_create_summary(session, user)
    await session.commit()
    return analytics_service.summary_to_out(row)
