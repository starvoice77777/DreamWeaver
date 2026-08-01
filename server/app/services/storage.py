from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
from typing import Protocol
from urllib.parse import urlparse, urlunparse

from minio import Minio
from minio.error import S3Error

from app.core.config import Settings, get_settings


@dataclass(frozen=True)
class ObjectStat:
    size: int
    content_type: str | None


class ObjectStorage(Protocol):
    def ensure_bucket(self) -> None: ...

    def presign_put(self, key: str, expires_seconds: int) -> str: ...

    def presign_get(self, key: str, expires_seconds: int) -> str: ...

    def stat(self, key: str) -> ObjectStat: ...

    def put_bytes(self, key: str, data: bytes, content_type: str) -> None: ...

    def delete_object(self, key: str) -> None: ...


class MinioObjectStorage:
    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()
        secure = self._settings.object_storage_secure
        self._client = Minio(
            self._settings.object_storage_endpoint,
            access_key=self._settings.object_storage_access_key,
            secret_key=self._settings.object_storage_secret_key,
            secure=secure,
        )
        self._bucket = self._settings.object_storage_bucket
        self._public_endpoint = (
            self._settings.object_storage_public_endpoint
            or self._settings.object_storage_endpoint
        )

    def ensure_bucket(self) -> None:
        if not self._client.bucket_exists(self._bucket):
            self._client.make_bucket(self._bucket)

    def presign_put(self, key: str, expires_seconds: int) -> str:
        self.ensure_bucket()
        url = self._client.presigned_put_object(
            self._bucket, key, expires=timedelta(seconds=expires_seconds)
        )
        return self._rewrite_host(url)

    def presign_get(self, key: str, expires_seconds: int) -> str:
        self.ensure_bucket()
        url = self._client.presigned_get_object(
            self._bucket, key, expires=timedelta(seconds=expires_seconds)
        )
        return self._rewrite_host(url)

    def stat(self, key: str) -> ObjectStat:
        try:
            info = self._client.stat_object(self._bucket, key)
        except S3Error as exc:
            if exc.code in {"NoSuchKey", "NoSuchObject", "NotFound"}:
                raise FileNotFoundError(key) from exc
            raise
        return ObjectStat(size=info.size or 0, content_type=info.content_type)

    def put_bytes(self, key: str, data: bytes, content_type: str) -> None:
        from io import BytesIO

        self.ensure_bucket()
        self._client.put_object(
            self._bucket,
            key,
            BytesIO(data),
            length=len(data),
            content_type=content_type,
        )

    def delete_object(self, key: str) -> None:
        try:
            self._client.remove_object(self._bucket, key)
        except S3Error as exc:
            if exc.code in {"NoSuchKey", "NoSuchObject", "NotFound"}:
                return
            raise

    def _rewrite_host(self, url: str) -> str:
        """Swap signing host for a client-reachable public endpoint when configured."""
        public = self._public_endpoint
        internal = self._settings.object_storage_endpoint
        if public == internal:
            return url
        parsed = urlparse(url)
        public_parsed = urlparse(
            public if "://" in public else f"{'https' if self._settings.object_storage_secure else 'http'}://{public}"
        )
        return urlunparse(
            (
                public_parsed.scheme or parsed.scheme,
                public_parsed.netloc or public,
                parsed.path,
                parsed.params,
                parsed.query,
                parsed.fragment,
            )
        )


class InMemoryObjectStorage:
    """Test double: stores bytes and returns fake presigned URLs."""

    def __init__(self) -> None:
        self.objects: dict[str, tuple[bytes, str]] = {}

    def ensure_bucket(self) -> None:
        return None

    def presign_put(self, key: str, expires_seconds: int) -> str:
        del expires_seconds
        return f"https://memory.local/put/{key}"

    def presign_get(self, key: str, expires_seconds: int) -> str:
        del expires_seconds
        return f"https://memory.local/get/{key}"

    def stat(self, key: str) -> ObjectStat:
        if key not in self.objects:
            raise FileNotFoundError(key)
        data, content_type = self.objects[key]
        return ObjectStat(size=len(data), content_type=content_type)

    def put_bytes(self, key: str, data: bytes, content_type: str) -> None:
        self.objects[key] = (data, content_type)

    def delete_object(self, key: str) -> None:
        self.objects.pop(key, None)


_storage: ObjectStorage | None = None


def get_object_storage() -> ObjectStorage:
    global _storage
    if _storage is None:
        _storage = MinioObjectStorage()
    return _storage


def set_object_storage(storage: ObjectStorage | None) -> None:
    global _storage
    _storage = storage
