from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.models.user import User
from app.services import auth as auth_service

DbSession = Annotated[AsyncSession, Depends(get_db_session)]


def extract_bearer_token(authorization: str | None) -> str:
    if authorization is None or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token


async def get_current_user(
    session: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    return await auth_service.resolve_user_by_access_token(
        session, extract_bearer_token(authorization)
    )


async def get_optional_user(
    session: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User | None:
    if authorization is None or not authorization.strip():
        return None
    return await auth_service.resolve_user_by_access_token(
        session, extract_bearer_token(authorization)
    )


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]
