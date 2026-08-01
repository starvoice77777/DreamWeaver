from celery import Celery  # type: ignore[import-untyped]

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "dreamweaver",
    broker=settings.redis_url,
    backend=settings.redis_url,
)
celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    task_track_started=True,
    timezone="Asia/Shanghai",
)


@celery_app.task(name="system.ping")  # type: ignore[untyped-decorator]
def ping() -> dict[str, str]:
    return {"status": "ok"}


@celery_app.task(name="seeds.advance_job")  # type: ignore[untyped-decorator]
def advance_job(job_id: str) -> dict[str, str]:
    """Optional worker skeleton; API poll path advances progress without Redis."""
    return {"job_id": job_id, "status": "noop"}

