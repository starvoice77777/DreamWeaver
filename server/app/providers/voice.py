from dataclasses import dataclass
from typing import Protocol
from uuid import UUID


@dataclass(frozen=True)
class VoiceJobResult:
    provider_job_id: str
    status: str
    output_storage_key: str | None = None


class VoiceProvider(Protocol):
    async def create_voice_job(
        self,
        *,
        job_id: UUID,
        source_storage_key: str,
        authorization_id: UUID,
    ) -> VoiceJobResult: ...

    async def get_job(self, provider_job_id: str) -> VoiceJobResult: ...

    async def delete_voice(self, provider_voice_id: str) -> None: ...


class StubVoiceProvider:
    """Local deterministic provider used until a production vendor is selected."""

    async def create_voice_job(
        self,
        *,
        job_id: UUID,
        source_storage_key: str,
        authorization_id: UUID,
    ) -> VoiceJobResult:
        del source_storage_key, authorization_id
        return VoiceJobResult(
            provider_job_id=f"stub-{job_id}",
            status="completed",
            output_storage_key=f"generated/{job_id}/preview.m4a",
        )

    async def get_job(self, provider_job_id: str) -> VoiceJobResult:
        return VoiceJobResult(provider_job_id=provider_job_id, status="completed")

    async def delete_voice(self, provider_voice_id: str) -> None:
        del provider_voice_id

