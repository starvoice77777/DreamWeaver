"""Dependency probes for /ready."""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def probe_database(session: AsyncSession) -> None:
    await session.execute(text("SELECT 1"))


async def probe_redis(redis_url: str) -> None:
    from redis.asyncio import Redis

    client: Redis = Redis.from_url(redis_url, socket_connect_timeout=1.0)
    try:
        await client.ping()
    finally:
        await client.aclose()
