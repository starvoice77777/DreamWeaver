from __future__ import annotations

import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.library import UserSoundAsset
from app.models.seed import SeedJob, VoiceAuthorization
from app.models.user import User
from app.providers.voice import StubVoiceProvider, VoiceProvider
from app.schemas.library import SoundAssetOut, utc_now
from app.schemas.seed import (
    ALLOWED_RELATIONS,
    JOB_MESSAGES,
    SeedAnalyzeIn,
    SeedFinalizeIn,
    SeedJobOut,
    SeedProcessIn,
    SeedQualityReportOut,
    VoiceAuthorizationCreate,
    VoiceAuthorizationOut,
)
from app.services.library import asset_to_out

DEFAULT_PURPOSE = "用于生成个人声音种子并在织梦场景中播放"
PROGRESS_STEP = 0.34


def _auth_to_out(row: VoiceAuthorization) -> VoiceAuthorizationOut:
    return VoiceAuthorizationOut(
        id=row.id,
        confirmed=row.confirmed,
        revocable=row.revocable,
        purpose=row.purpose,
        revoked_at=row.revoked_at,
        created_at=row.created_at,
    )


def _job_to_out(row: SeedJob) -> SeedJobOut:
    return SeedJobOut(
        id=row.id,
        status=row.status,
        progress=row.progress,
        message=row.message,
        preview_storage_key=row.preview_storage_key,
        result_asset_id=row.result_asset_id,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def get_voice_provider() -> VoiceProvider:
    return StubVoiceProvider()


async def create_authorization(
    session: AsyncSession,
    user: User,
    body: VoiceAuthorizationCreate,
) -> VoiceAuthorizationOut:
    if not body.confirmed:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Authorization must be confirmed",
        )
    row = VoiceAuthorization(
        user_id=user.id,
        confirmed=True,
        revocable=True,
        purpose=(body.purpose or DEFAULT_PURPOSE).strip()[:512] or DEFAULT_PURPOSE,
    )
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return _auth_to_out(row)


async def list_authorizations(session: AsyncSession, user: User) -> list[VoiceAuthorizationOut]:
    result = await session.scalars(
        select(VoiceAuthorization)
        .where(VoiceAuthorization.user_id == user.id)
        .order_by(VoiceAuthorization.created_at.desc())
    )
    return [_auth_to_out(row) for row in result.all()]


async def revoke_authorization(
    session: AsyncSession, user: User, authorization_id: uuid.UUID
) -> VoiceAuthorizationOut:
    result = await session.scalars(
        select(VoiceAuthorization).where(
            VoiceAuthorization.id == authorization_id,
            VoiceAuthorization.user_id == user.id,
        )
    )
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Authorization not found")
    if row.revoked_at is None:
        if not row.revocable:
            raise HTTPException(status_code=409, detail="Authorization is not revocable")
        row.revoked_at = utc_now()
        await session.commit()
        await session.refresh(row)
    return _auth_to_out(row)


async def analyze(_user: User, body: SeedAnalyzeIn) -> SeedQualityReportOut:
    duration = body.duration_seconds
    passed = duration >= 3
    return SeedQualityReportOut(
        clarity="良好" if passed else "偏弱",
        noise_level="较低" if passed else "偏高",
        effective_duration_seconds=duration,
        recommendation="可以直接继续" if passed else "建议重新录制，时长至少 3 秒",
        passed=passed,
    )


async def _owned_active_auth(
    session: AsyncSession, user: User, authorization_id: uuid.UUID
) -> VoiceAuthorization:
    result = await session.scalars(
        select(VoiceAuthorization).where(
            VoiceAuthorization.id == authorization_id,
            VoiceAuthorization.user_id == user.id,
        )
    )
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Authorization not found")
    if row.revoked_at is not None:
        raise HTTPException(status_code=409, detail="Authorization has been revoked")
    if not row.confirmed:
        raise HTTPException(status_code=409, detail="Authorization not confirmed")
    return row


async def _owned_asset(
    session: AsyncSession, user: User, asset_id: uuid.UUID
) -> UserSoundAsset:
    result = await session.scalars(
        select(UserSoundAsset).where(
            UserSoundAsset.id == asset_id,
            UserSoundAsset.owner_user_id == user.id,
            UserSoundAsset.deleted_at.is_(None),
        )
    )
    asset = result.first()
    if asset is None:
        raise HTTPException(status_code=404, detail="Source asset not found")
    return asset


async def start_process(
    session: AsyncSession,
    user: User,
    body: SeedProcessIn,
    *,
    provider: VoiceProvider | None = None,
) -> SeedJobOut:
    provider = provider or get_voice_provider()
    auth = await _owned_active_auth(session, user, body.authorization_id)
    source = await _owned_asset(session, user, body.source_asset_id)

    job_id = uuid.uuid4()
    voice_result = await provider.create_voice_job(
        job_id=job_id,
        source_storage_key=source.storage_key,
        authorization_id=auth.id,
    )
    row = SeedJob(
        id=job_id,
        user_id=user.id,
        authorization_id=auth.id,
        source_asset_id=source.id,
        status="processing",
        progress=0.0,
        message=JOB_MESSAGES[0],
        provider_job_id=voice_result.provider_job_id,
        preview_storage_key=voice_result.output_storage_key,
    )
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return _job_to_out(row)


async def _owned_job(session: AsyncSession, user: User, job_id: uuid.UUID) -> SeedJob:
    result = await session.scalars(
        select(SeedJob).where(
            SeedJob.id == job_id,
            SeedJob.user_id == user.id,
            SeedJob.deleted_at.is_(None),
        )
    )
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Seed job not found")
    return row


async def get_job(session: AsyncSession, user: User, job_id: uuid.UUID) -> SeedJobOut:
    row = await _owned_job(session, user, job_id)
    if row.status in {"completed", "failed", "cancelled"}:
        return _job_to_out(row)

    next_progress = min(row.progress + PROGRESS_STEP, 1.0)
    row.progress = next_progress
    if next_progress >= 1.0:
        row.status = "completed"
        row.message = "已准备好试听版本"
        row.progress = 1.0
    else:
        row.status = "processing"
        idx = min(int(next_progress * len(JOB_MESSAGES)), len(JOB_MESSAGES) - 1)
        row.message = JOB_MESSAGES[idx]
    row.updated_at = utc_now()
    await session.commit()
    await session.refresh(row)
    return _job_to_out(row)


async def finalize_job(
    session: AsyncSession,
    user: User,
    job_id: uuid.UUID,
    body: SeedFinalizeIn,
) -> SoundAssetOut:
    row = await _owned_job(session, user, job_id)
    if row.status != "completed":
        raise HTTPException(status_code=409, detail="Seed job is not completed yet")
    if row.result_asset_id is not None:
        existing = await session.scalars(
            select(UserSoundAsset).where(UserSoundAsset.id == row.result_asset_id)
        )
        asset = existing.first()
        if asset is None:
            raise HTTPException(status_code=500, detail="Finalized job missing asset")
        return asset_to_out(asset)

    relation = body.relation.strip()
    if relation not in ALLOWED_RELATIONS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Unsupported relation; allowed: {sorted(ALLOWED_RELATIONS)}",
        )

    source = await _owned_asset(session, user, row.source_asset_id)
    storage_key = row.preview_storage_key or f"generated/{row.id}/preview.m4a"
    asset = UserSoundAsset(
        owner_user_id=user.id,
        upload_id=None,
        name=body.name.strip()[:128] or "新的声音种子",
        kind="voice",
        symbol_name="leaf.fill",
        duration_seconds=max(source.duration_seconds, 1),
        content_type=source.content_type or "audio/mp4",
        byte_size=max(source.byte_size, 1),
        storage_key=storage_key,
        processing_status="ready",
    )
    session.add(asset)
    await session.flush()
    row.result_asset_id = asset.id
    row.relation = relation
    row.updated_at = utc_now()
    await session.commit()
    await session.refresh(asset)
    return asset_to_out(asset)


async def delete_job(session: AsyncSession, user: User, job_id: uuid.UUID) -> None:
    row = await _owned_job(session, user, job_id)
    if row.status == "completed" and row.result_asset_id is not None:
        raise HTTPException(status_code=409, detail="Cannot delete a finalized seed job")
    row.status = "cancelled"
    row.deleted_at = utc_now()
    row.updated_at = utc_now()
    await session.commit()
