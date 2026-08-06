from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

EventType = Literal["scene_listen", "session_ended", "seed_created", "mix_edited"]


class AnalyticsEventIn(BaseModel):
    type: EventType
    scene_id: uuid.UUID | None = None
    asset_id: uuid.UUID | None = None
    duration_seconds: int | None = Field(default=None, ge=0)
    occurred_at: datetime | None = None
    idempotency_key: str | None = Field(default=None, max_length=128)


class AnalyticsEventsBatchIn(BaseModel):
    events: list[AnalyticsEventIn] = Field(default_factory=list, max_length=100)


class AnalyticsEventsAcceptedOut(BaseModel):
    accepted: int
    skipped_duplicates: int = 0


class UsageSummaryOut(BaseModel):
    """Aligned with iOS UsageRecord (snake_case wire format)."""

    id: uuid.UUID
    total_minutes: int
    week_minutes: int
    usual_bedtime: str
    last_used_at: datetime
    sleep_trend: list[int]
