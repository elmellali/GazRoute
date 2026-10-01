"""Tenant-scoped repository helpers. Every query MUST filter by tenant_id."""
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import NotFound


def tenant_select(model, tenant_id: UUID):
    return select(model).where(model.tenant_id == tenant_id)


def get_tenant_scoped(db: Session, model, tenant_id: UUID, entity_id: UUID, not_found: str = "Not found"):
    obj = db.execute(tenant_select(model, tenant_id).where(model.id == entity_id)).scalar_one_or_none()
    if obj is None:
        raise NotFound(not_found)
    return obj


def list_tenant(db: Session, model, tenant_id: UUID, *, limit: int = 100, offset: int = 0):
    return list(
        db.execute(
            tenant_select(model, tenant_id).limit(limit).offset(offset).order_by(model.created_at.desc())
        ).scalars()
    )
