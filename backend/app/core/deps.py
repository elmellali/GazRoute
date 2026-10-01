from dataclasses import dataclass
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import Forbidden, Unauthorized
from app.core.security import decode_token, is_revoked

bearer_scheme = HTTPBearer(auto_error=False)

ROLE_OWNER = "owner"
ROLE_DISPATCHER = "dispatcher"
ROLE_WAREHOUSE = "warehouse"
ROLE_AGENT = "agent"
ROLE_ACCOUNTANT = "accountant"
ROLE_AUDITOR = "auditor"

ALL_ROLES = {
    ROLE_OWNER,
    ROLE_DISPATCHER,
    ROLE_WAREHOUSE,
    ROLE_AGENT,
    ROLE_ACCOUNTANT,
    ROLE_AUDITOR,
}


@dataclass(frozen=True)
class AuthContext:
    user_id: UUID
    tenant_id: UUID
    role: str
    device_id: str | None
    jti: str


def get_auth_context(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> AuthContext:
    if credentials is None or not credentials.credentials:
        raise Unauthorized()
    try:
        payload = decode_token(credentials.credentials)
    except Exception:
        raise Unauthorized("Invalid or expired token")
    if payload.get("type") != "access":
        raise Unauthorized("Access token required")
    jti = payload.get("jti") or ""
    if jti and is_revoked(jti):
        raise Unauthorized("Token revoked")
    try:
        return AuthContext(
            user_id=UUID(payload["sub"]),
            tenant_id=UUID(payload["tenant_id"]),
            role=payload["role"],
            device_id=payload.get("device_id"),
            jti=jti,
        )
    except (KeyError, ValueError):
        raise Unauthorized("Malformed token payload")


AuthDep = Annotated[AuthContext, Depends(get_auth_context)]
DbDep = Annotated[Session, Depends(get_db)]


def require_roles(*roles: str):
    def checker(ctx: AuthDep) -> AuthContext:
        if ctx.role not in roles:
            raise Forbidden(f"Role '{ctx.role}' not permitted")
        return ctx

    return checker


def require_any_role(request: Request) -> None:
    return None


IdempotencyKey = Annotated[str | None, Header(alias="Idempotency-Key")]
