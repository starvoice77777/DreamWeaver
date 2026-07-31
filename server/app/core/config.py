from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="DW_",
        extra="ignore",
    )

    app_name: str = "DreamWeaver API"
    environment: str = "development"
    debug: bool = False
    api_v1_prefix: str = "/v1"

    database_url: str = "postgresql+asyncpg://dreamweaver:dreamweaver@localhost:5432/dreamweaver"
    redis_url: str = "redis://localhost:6379/0"

    object_storage_endpoint: str = "localhost:9000"
    object_storage_access_key: str = "dreamweaver"
    object_storage_secret_key: str = Field(default="dreamweaver-local-only", repr=False)
    object_storage_bucket: str = "dreamweaver-private"
    object_storage_secure: bool = False

    voice_provider: str = "stub"


@lru_cache
def get_settings() -> Settings:
    return Settings()

