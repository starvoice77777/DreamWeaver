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

    # Sign in with Apple — audience is the iOS Bundle ID (or Services ID for web).
    apple_client_id: str = "zhimeng.DreamWeaver"
    apple_issuer: str = "https://appleid.apple.com"
    apple_jwks_url: str = "https://appleid.apple.com/auth/keys"
    apple_jwks_cache_seconds: int = 3600
    # When true, POST /v1/auth/apple accepts identity_token "dev:<apple_sub>".
    # Defaults to true only in development; set explicitly in production.
    allow_dev_apple_auth: bool | None = None

    @property
    def dev_apple_auth_enabled(self) -> bool:
        if self.allow_dev_apple_auth is not None:
            return self.allow_dev_apple_auth
        return self.environment.lower() in {"development", "test", "local"}


@lru_cache
def get_settings() -> Settings:
    return Settings()

