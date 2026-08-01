from __future__ import annotations

import uuid

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.schemas.library import SoundAssetOut
from app.schemas.seed import (
    SeedAnalyzeIn,
    SeedFinalizeIn,
    SeedJobOut,
    SeedProcessIn,
    SeedQualityReportOut,
    VoiceAuthorizationCreate,
    VoiceAuthorizationOut,
    VoiceAuthorizationRevokeOut,
)
from app.services import seed as seed_service

router = APIRouter(tags=["seeds"])


@router.post(
    "/voice-authorizations",
    response_model=VoiceAuthorizationOut,
    summary="Create creator voice authorization record",
)
async def create_authorization(
    body: VoiceAuthorizationCreate, session: DbSession, user: CurrentUser
) -> VoiceAuthorizationOut:
    return await seed_service.create_authorization(session, user, body)


@router.get(
    "/voice-authorizations",
    response_model=list[VoiceAuthorizationOut],
    summary="List voice authorizations for current user",
)
async def list_authorizations(
    session: DbSession, user: CurrentUser
) -> list[VoiceAuthorizationOut]:
    return await seed_service.list_authorizations(session, user)


@router.post(
    "/voice-authorizations/{authorization_id}/revoke",
    response_model=VoiceAuthorizationRevokeOut,
    summary="Revoke authorization and cascade-cancel jobs / seed assets",
)
async def revoke_authorization(
    authorization_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> VoiceAuthorizationRevokeOut:
    return await seed_service.revoke_authorization(session, user, authorization_id)


@router.post(
    "/seeds/analyze",
    response_model=SeedQualityReportOut,
    summary="Analyze seed sample quality (stub)",
)
async def analyze_seed(
    body: SeedAnalyzeIn, user: CurrentUser
) -> SeedQualityReportOut:
    return await seed_service.analyze(user, body)


@router.post(
    "/seeds/process",
    response_model=SeedJobOut,
    summary="Start seed processing job via StubVoiceProvider",
)
async def process_seed(
    body: SeedProcessIn, session: DbSession, user: CurrentUser
) -> SeedJobOut:
    return await seed_service.start_process(session, user, body)


@router.get(
    "/seeds/jobs/{job_id}",
    response_model=SeedJobOut,
    summary="Poll seed job (advances stub progress)",
)
async def get_seed_job(
    job_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> SeedJobOut:
    return await seed_service.get_job(session, user, job_id)


@router.post(
    "/seeds/jobs/{job_id}/finalize",
    response_model=SoundAssetOut,
    summary="Finalize completed job into a voice SoundAsset",
)
async def finalize_seed_job(
    job_id: uuid.UUID,
    body: SeedFinalizeIn,
    session: DbSession,
    user: CurrentUser,
) -> SoundAssetOut:
    return await seed_service.finalize_job(session, user, job_id, body)


@router.delete(
    "/seeds/jobs/{job_id}",
    status_code=204,
    summary="Cancel an unfinished seed job",
)
async def delete_seed_job(
    job_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> None:
    await seed_service.delete_job(session, user, job_id)
