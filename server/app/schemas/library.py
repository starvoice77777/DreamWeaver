from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from pydantic import BaseModel, Field


ALLOWED_EXTENSIONS = {"m4a", "mp3", "wav", "caf"}
ALLOWED_CONTENT_TYPES = {
    "audio/mp4",
    "audio/m4a",
    "audio/x-m4a",
    "audio/mpeg",
    "audio/mp3",
    "audio/wav",
    "audio/x-wav",
    "audio/wave",
    "audio/x-caf",
    "audio/caf",
}
ALLOWED_KINDS = {"life", "voice", "environment", "official"}


class UploadCreate(BaseModel):
    filename: str = Field(min_length=1, max_length=256)
    content_type: str = Field(min_length=3, max_length=128)
    byte_size: int = Field(gt=0)
    kind: str = Field(default="life", max_length=64)
    name: str | None = Field(default=None, max_length=128)
    duration_seconds: int = Field(default=0, ge=0, le=86_400)


class UploadSessionOut(BaseModel):
    upload_id: uuid.UUID
    put_url: str
    storage_key: str
    required_headers: dict[str, str]
    expires_at: datetime
    max_byte_size: int


class SoundAssetOut(BaseModel):
    id: uuid.UUID
    name: str
    kind: str
    symbol_name: str
    duration_seconds: int
    content_type: str
    byte_size: int
    is_favorite: bool
    processing_status: str
    created_at: datetime
    updated_at: datetime


class PlaybackUrlOut(BaseModel):
    asset_id: uuid.UUID
    url: str
    expires_at: datetime


class SoundAssetPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=128)
    symbol_name: str | None = Field(default=None, min_length=1, max_length=128)
    is_favorite: bool | None = None


class AffectedSceneOut(BaseModel):
    id: uuid.UUID
    name: str
    draft_reference_count: int
    saved_reference_count: int


class DeleteImpactOut(BaseModel):
    asset_id: uuid.UUID
    affected_scenes: list[AffectedSceneOut]
    total_references: int


class DeleteAssetOut(BaseModel):
    asset_id: uuid.UUID
    deleted: bool
    scrubbed_scene_ids: list[uuid.UUID]
    storage_deleted: bool


def utc_now() -> datetime:
    return datetime.now(UTC)


def expires_in(seconds: int) -> datetime:
    return utc_now() + timedelta(seconds=seconds)
