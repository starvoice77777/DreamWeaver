"""Append audit rows + structured audit log lines."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import get_logger
from app.core.request_context import get_request_id
from app.models.audit import AuditEvent

logger = get_logger("dreamweaver.audit")


async def record_audit(
    session: AsyncSession,
    *,
    action: str,
    user_id: uuid.UUID | None = None,
    resource_type: str | None = None,
    resource_id: str | uuid.UUID | None = None,
    detail: dict[str, Any] | None = None,
) -> AuditEvent:
    """Queue an audit event on the session (caller commits)."""
    request_id = get_request_id()
    rid = str(resource_id) if resource_id is not None else None
    event = AuditEvent(
        user_id=user_id,
        action=action,
        resource_type=resource_type,
        resource_id=rid,
        request_id=request_id,
        detail=detail or {},
    )
    session.add(event)
    logger.info(
        "audit",
        extra={
            "request_id": request_id,
            "action": action,
            "user_id": str(user_id) if user_id else None,
            "resource_type": resource_type,
            "resource_id": rid,
        },
    )
    return event
