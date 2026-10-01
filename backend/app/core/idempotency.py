import hashlib
import json
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import IdempotencyConflict
from app.models import IdempotencyRecord


def payload_hash(body: Any) -> str:
    canonical = json.dumps(body, sort_keys=True, default=str)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def get_replay(db: Session, *, tenant_id, key: str, request_hash: str) -> IdempotencyRecord | None:
    rec = db.execute(
        select(IdempotencyRecord).where(
            IdempotencyRecord.tenant_id == tenant_id,
            IdempotencyRecord.idempotency_key == key,
        )
    ).scalar_one_or_none()
    if rec is None:
        return None
    if rec.request_hash != request_hash:
        raise IdempotencyConflict()
    return rec


def save_replay(
    db: Session,
    *,
    tenant_id,
    key: str,
    request_hash: str,
    response_status: int,
    response_body: dict,
) -> IdempotencyRecord:
    rec = IdempotencyRecord(
        tenant_id=tenant_id,
        idempotency_key=key,
        request_hash=request_hash,
        response_status=response_status,
        response_body=response_body,
    )
    db.add(rec)
    db.flush()
    return rec
