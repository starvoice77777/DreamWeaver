from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

ALLOWED_RELATIONS = {
    "家人",
    "伴侣",
    "朋友",
    "自定义",
    "family",
    "partner",
    "friend",
    "custom",
}

JOB_MESSAGES = [
    "正在整理声音片段",
    "正在保留声音特点",
    "正在准备试听版本",
]


class VoiceAuthorizationCreate(BaseModel):
    confirmed: bool = True
    purpose: str | None = Field(default=None, max_length=512)


class VoiceAuthorizationOut(BaseModel):
    id: uuid.UUID
    confirmed: bool
    revocable: bool
    purpose: str
    revoked_at: datetime | None
    created_at: datetime


class VoiceAuthorizationRevokeOut(VoiceAuthorizationOut):
    cancelled_jobs: int = 0
    deleted_assets: int = 0
    scrubbed_scene_ids: list[uuid.UUID] = Field(default_factory=list)
    provider_deletes: int = 0


class SeedAnalyzeIn(BaseModel):
    duration_seconds: int = Field(ge=0, le=86_400)


class SeedQualityReportOut(BaseModel):
    clarity: str
    noise_level: str
    effective_duration_seconds: int
    recommendation: str
    passed: bool


class SeedProcessIn(BaseModel):
    authorization_id: uuid.UUID
    source_asset_id: uuid.UUID


class SeedJobOut(BaseModel):
    id: uuid.UUID
    status: str
    progress: float
    message: str
    preview_storage_key: str | None = None
    result_asset_id: uuid.UUID | None = None
    created_at: datetime
    updated_at: datetime


class SeedFinalizeIn(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    relation: str = Field(default="家人", max_length=64)
