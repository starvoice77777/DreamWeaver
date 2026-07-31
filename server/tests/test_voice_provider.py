from uuid import uuid4

from app.providers.voice import StubVoiceProvider


async def test_stub_voice_provider_is_deterministic() -> None:
    provider = StubVoiceProvider()
    job_id = uuid4()

    result = await provider.create_voice_job(
        job_id=job_id,
        source_storage_key="uploads/source.wav",
        authorization_id=uuid4(),
    )

    assert result.provider_job_id == f"stub-{job_id}"
    assert result.status == "completed"
    assert result.output_storage_key == f"generated/{job_id}/preview.m4a"

