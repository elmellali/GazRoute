from uuid import UUID

from sqlalchemy.orm import Session

from app.models import AuditLog


def write_audit(
    db: Session,
    *,
    tenant_id: UUID,
    actor_id: UUID,
    action: str,
    target_entity: str,
    target_id: UUID,
    before_state: dict | None = None,
    after_state: dict | None = None,
    ip_address: str | None = None,
) -> AuditLog:
    entry = AuditLog(
        tenant_id=tenant_id,
        actor_id=actor_id,
        action=action,
        target_entity=target_entity,
        target_id=target_id,
        before_state=before_state,
        after_state=after_state,
        ip_address=ip_address,
    )
    db.add(entry)
    db.flush()
    return entry
