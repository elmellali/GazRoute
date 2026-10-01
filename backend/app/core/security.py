from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import settings

_hasher = PasswordHasher()

# In-memory revocation list (dev fallback for Redis blacklist)
_revoked_jti: set[str] = set()


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str | None, password: str) -> bool:
    if not password_hash:
        return False
    try:
        return _hasher.verify(password_hash, password)
    except VerifyMismatchError:
        return False


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(
    *,
    user_id: UUID,
    tenant_id: UUID,
    role: str,
    device_id: str | None = None,
    jti: str | None = None,
) -> str:
    now = _now()
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "role": role,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=settings.access_token_expire_minutes),
        "jti": jti or __import__("uuid").uuid4().hex,
    }
    if device_id:
        payload["device_id"] = device_id
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def create_refresh_token(
    *,
    user_id: UUID,
    tenant_id: UUID,
    role: str,
    device_id: str | None = None,
) -> str:
    now = _now()
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "role": role,
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=settings.refresh_token_expire_days),
        "jti": __import__("uuid").uuid4().hex,
    }
    if device_id:
        payload["device_id"] = device_id
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def decode_token(token: str) -> dict[str, Any]:
    return jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])


def revoke_jti(jti: str) -> None:
    _revoked_jti.add(jti)


def is_revoked(jti: str) -> bool:
    return jti in _revoked_jti


def generate_otp_code() -> str:
    import secrets

    return f"{secrets.randbelow(1_000_000):06d}"
