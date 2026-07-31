from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, String, Uuid, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import JSON

from app.db.base import Base

JSONType = JSON().with_variant(JSONB(), "postgresql")


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nickname: Mapped[str] = mapped_column(String(64), nullable=False, default="夜行者")
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="active")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    apple_identity: Mapped[AppleIdentity | None] = relationship(
        back_populates="user", uselist=False
    )
    sessions: Mapped[list[Session]] = relationship(back_populates="user")
    settings: Mapped[UserSettings | None] = relationship(back_populates="user", uselist=False)


class AppleIdentity(Base):
    __tablename__ = "apple_identities"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    apple_sub: Mapped[str] = mapped_column(String(128), unique=True, nullable=False, index=True)
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped[User] = relationship(back_populates="apple_identity")


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    refresh_token_hash: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    access_token_hash: Mapped[str] = mapped_column(
        String(128), unique=True, nullable=False, index=True
    )
    device_label: Mapped[str | None] = mapped_column(String(128), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped[User] = relationship(back_populates="sessions")


class UserSettings(Base):
    __tablename__ = "user_settings"

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    reduce_motion: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    auto_play_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    background_play_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    lock_screen_play_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    animation_intensity: Mapped[float] = mapped_column(Float, nullable=False, default=0.7)
    dark_mode_forced: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    audio_quality: Mapped[str] = mapped_column(String(32), nullable=False, default="标准")
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    default_scene_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), nullable=True)
    extras: Mapped[dict] = mapped_column(JSONType, nullable=False, default=dict)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped[User] = relationship(back_populates="settings")
