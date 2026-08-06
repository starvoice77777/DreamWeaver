from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, Uuid, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import JSON

from app.db.base import Base

JSONType = JSON().with_variant(JSONB(), "postgresql")


class Scene(Base):
    __tablename__ = "scenes"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(256), nullable=False, default="")
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    category: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    tags: Mapped[list] = mapped_column(JSONType, nullable=False, default=list)
    palette: Mapped[dict] = mapped_column(JSONType, nullable=False, default=dict)
    visual_style: Mapped[str] = mapped_column(String(64), nullable=False)
    recommended_duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=2700)
    is_demo_playable: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_published: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    mock_listener_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    tracks: Mapped[list[SceneTrack]] = relationship(
        back_populates="scene", cascade="all, delete-orphan", order_by="SceneTrack.sort_order"
    )
    mix_presets: Mapped[list[MixPreset]] = relationship(
        back_populates="scene", cascade="all, delete-orphan"
    )
    timeline: Mapped[SceneTimeline | None] = relationship(
        back_populates="scene", cascade="all, delete-orphan", uselist=False
    )


class SceneTimeline(Base):
    """Versioned cue/phrase document executed by the client playback scheduler."""

    __tablename__ = "scene_timelines"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scene_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("scenes.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    automation_mode: Mapped[str] = mapped_column(
        String(32), nullable=False, default="official_auto"
    )
    duration_hint_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    override_policy: Mapped[str] = mapped_column(
        String(64), nullable=False, default="per_source_manual_exit"
    )
    phrases: Mapped[list] = mapped_column(JSONType, nullable=False, default=list)
    cues: Mapped[list] = mapped_column(JSONType, nullable=False, default=list)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    scene: Mapped[Scene] = relationship(back_populates="timeline")


class SceneTrack(Base):
    __tablename__ = "scene_tracks"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scene_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("scenes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    symbol_name: Mapped[str] = mapped_column(String(128), nullable=False)
    layer: Mapped[str] = mapped_column(String(32), nullable=False, default="environment")
    volume: Mapped[float] = mapped_column(Float, nullable=False, default=0.7)
    angle: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    radius: Mapped[float] = mapped_column(Float, nullable=False, default=0.55)
    resource_key: Mapped[str | None] = mapped_column(String(256), nullable=True)
    loop: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    enabled_by_default: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    scene: Mapped[Scene] = relationship(back_populates="tracks")


class MixPreset(Base):
    __tablename__ = "mix_presets"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scene_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("scenes.id", ondelete="SET NULL"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    style_hint: Mapped[str | None] = mapped_column(String(64), nullable=True)
    author_name: Mapped[str] = mapped_column(String(64), nullable=False, default="织梦")
    sources: Mapped[list] = mapped_column(JSONType, nullable=False, default=list)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_published: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    scene: Mapped[Scene | None] = relationship(back_populates="mix_presets")


class OfficialAsset(Base):
    __tablename__ = "official_assets"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    kind: Mapped[str] = mapped_column(String(64), nullable=False, default="environment")
    symbol_name: Mapped[str] = mapped_column(String(128), nullable=False, default="waveform")
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    resource_key: Mapped[str | None] = mapped_column(String(256), nullable=True)
    preview_resource_key: Mapped[str | None] = mapped_column(String(256), nullable=True)
    tags: Mapped[list] = mapped_column(JSONType, nullable=False, default=list)
    is_published: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
