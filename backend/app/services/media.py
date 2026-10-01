"""Local media store with pre-signed-style short-lived tokens (dev stub for S3)."""
import hashlib
import secrets
import time
from pathlib import Path
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.exceptions import NotFound, ValidationException
from app.models import MediaObject


def media_root() -> Path:
    p = Path(settings.media_root).resolve()
    p.mkdir(parents=True, exist_ok=True)
    return p


def create_upload_token(
    db: Session,
    *,
    tenant_id: UUID,
    kind: str = "image",
    content_type: str | None = None,
    uploaded_by: UUID | None = None,
) -> dict:
    token = f"med_{secrets.token_urlsafe(16)}"
    rel = f"{tenant_id}/{token}"
    path = media_root() / str(tenant_id) / token
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"")
    obj = MediaObject(
        tenant_id=tenant_id,
        media_token=token,
        kind=kind,
        storage_path=str(path),
        content_type=content_type,
        uploaded_by=uploaded_by,
    )
    db.add(obj)
    db.flush()
    expires = int(time.time()) + settings.presigned_ttl_minutes * 60
    return {
        "media_token": token,
        "upload_url": f"/api/v1/media/{token}/upload",
        "expires_in_seconds": settings.presigned_ttl_minutes * 60,
        "expires_at": expires,
    }


def write_media(db: Session, tenant_id: UUID, token: str, data: bytes, content_type: str | None = None) -> MediaObject:
    obj = db.execute(
        MediaObject.__table__.select().where(
            MediaObject.tenant_id == tenant_id,
            MediaObject.media_token == token,
        )
    ).first()
    # use ORM
    from sqlalchemy import select

    obj = db.execute(
        select(MediaObject).where(
            MediaObject.tenant_id == tenant_id, MediaObject.media_token == token
        )
    ).scalar_one_or_none()
    if obj is None:
        raise NotFound("Media token not found")
    Path(obj.storage_path).write_bytes(data)
    if content_type:
        obj.content_type = content_type
    db.flush()
    return obj


def presign_download(db: Session, tenant_id: UUID, token: str) -> dict:
    from sqlalchemy import select

    obj = db.execute(
        select(MediaObject).where(
            MediaObject.tenant_id == tenant_id, MediaObject.media_token == token
        )
    ).scalar_one_or_none()
    if obj is None:
        raise NotFound("Media not found")
    expires = int(time.time()) + settings.presigned_ttl_minutes * 60
    sig = hashlib.sha256(f"{token}:{expires}:{settings.secret_key}".encode()).hexdigest()[:32]
    return {
        "media_token": token,
        "download_url": f"/api/v1/media/{token}/download?exp={expires}&sig={sig}",
        "expires_in_seconds": settings.presigned_ttl_minutes * 60,
    }


def verify_download_sig(token: str, exp: int, sig: str) -> bool:
    import hmac

    if int(time.time()) > int(exp):
        return False
    expected = hashlib.sha256(f"{token}:{exp}:{settings.secret_key}".encode()).hexdigest()[:32]
    return hmac.compare_digest(expected, sig)


def read_media(db: Session, tenant_id: UUID, token: str) -> tuple[bytes, str | None]:
    from sqlalchemy import select

    obj = db.execute(
        select(MediaObject).where(
            MediaObject.tenant_id == tenant_id, MediaObject.media_token == token
        )
    ).scalar_one_or_none()
    if obj is None:
        raise NotFound("Media not found")
    path = Path(obj.storage_path)
    if not path.exists():
        raise NotFound("Media file missing")
    return path.read_bytes(), obj.content_type
