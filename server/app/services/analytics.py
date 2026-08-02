"""Companionship analytics: event ingest and usage summary."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.analytics import AnalyticsEvent, UsageSummary
from app.models.user import User
from app.schemas.analytics import AnalyticsEventIn, UsageSummaryOut

DEFAULT_TREND = [0, 0, 0, 0, 0, 0, 0]
DEFAULT_BEDTIME = "23:20"


async def get_or_create_summary(session: AsyncSession, user: User) -> UsageSummary:
    row = await session.get(UsageSummary, user.id)
    if row is not None:
        return row
    row = UsageSummary(
        user_id=user.id,
        id=uuid.uuid4(),
        total_minutes=0,
        week_minutes=0,
        usual_bedtime=DEFAULT_BEDTIME,
        last_used_at=datetime.now(timezone.utc),
        sleep_trend=list(DEFAULT_TREND),
    )
    session.add(row)
    await session.flush()
    return row


def summary_to_out(row: UsageSummary) -> UsageSummaryOut:
    trend = row.sleep_trend if isinstance(row.sleep_trend, list) else list(DEFAULT_TREND)
    if len(trend) < 7:
        trend = list(trend) + [0] * (7 - len(trend))
    elif len(trend) > 7:
        trend = list(trend)[:7]
    return UsageSummaryOut(
        id=row.id,
        total_minutes=row.total_minutes,
        week_minutes=row.week_minutes,
        usual_bedtime=row.usual_bedtime,
        last_used_at=row.last_used_at,
        sleep_trend=[int(x) for x in trend],
    )


def _bump_trend(row: UsageSummary, minutes: int) -> None:
    trend = list(row.sleep_trend) if isinstance(row.sleep_trend, list) else list(DEFAULT_TREND)
    if not trend:
        trend = list(DEFAULT_TREND)
    trend[-1] = int(trend[-1]) + minutes
    row.sleep_trend = trend


def _apply_event_to_summary(row: UsageSummary, event: AnalyticsEventIn, occurred: datetime) -> None:
    row.last_used_at = occurred
    if event.type == "scene_listen":
        row.total_minutes += 1
        row.week_minutes += 1
        _bump_trend(row, 1)
    elif event.type == "session_ended":
        minutes = max((event.duration_seconds or 0) // 60, 1)
        row.total_minutes += minutes
        row.week_minutes += minutes
        _bump_trend(row, minutes)
    # seed_created / mix_edited: touch last_used_at only (already set)


async def ingest_events(
    session: AsyncSession,
    user: User,
    events: list[AnalyticsEventIn],
) -> tuple[int, int]:
    """Insert events and update summary. Returns (accepted, skipped_duplicates)."""
    if not events:
        return 0, 0

    summary = await get_or_create_summary(session, user)
    accepted = 0
    skipped = 0

    for item in events:
        if item.idempotency_key:
            existing = await session.scalar(
                select(AnalyticsEvent.id).where(
                    AnalyticsEvent.user_id == user.id,
                    AnalyticsEvent.idempotency_key == item.idempotency_key,
                )
            )
            if existing is not None:
                skipped += 1
                continue

        occurred = item.occurred_at or datetime.now(timezone.utc)
        if occurred.tzinfo is None:
            occurred = occurred.replace(tzinfo=timezone.utc)

        session.add(
            AnalyticsEvent(
                id=uuid.uuid4(),
                user_id=user.id,
                event_type=item.type,
                scene_id=item.scene_id,
                asset_id=item.asset_id,
                duration_seconds=item.duration_seconds,
                idempotency_key=item.idempotency_key,
                client_occurred_at=occurred,
            )
        )
        _apply_event_to_summary(summary, item, occurred)
        accepted += 1

    await session.commit()
    await session.refresh(summary)
    return accepted, skipped
