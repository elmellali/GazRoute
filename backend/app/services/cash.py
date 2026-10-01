"""Receipt numbering and cash handover helpers."""
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import CashHandover, DeliveryNote, Payment


def next_delivery_receipt(db: Session, tenant_id: UUID, when: datetime | None = None) -> str:
    when = when or datetime.now(timezone.utc)
    prefix = f"DN-{when.strftime('%Y-%m%d')}-"
    count = db.execute(
        select(func.count(DeliveryNote.id)).where(
            DeliveryNote.tenant_id == tenant_id,
            DeliveryNote.receipt_number.like(prefix + "%"),
        )
    ).scalar_one()
    return f"{prefix}{count + 1:04d}"


def next_payment_receipt(db: Session, tenant_id: UUID, when: datetime | None = None) -> str:
    when = when or datetime.now(timezone.utc)
    prefix = f"PY-{when.strftime('%Y-%m%d')}-"
    count = db.execute(
        select(func.count(Payment.id)).where(
            Payment.tenant_id == tenant_id,
            Payment.receipt_number.like(prefix + "%"),
        )
    ).scalar_one()
    return f"{prefix}{count + 1:04d}"


def expected_cash_for_shift(db: Session, tenant_id: UUID, shift_id: UUID) -> Decimal:
    total = db.execute(
        select(func.coalesce(func.sum(Payment.amount_mad), 0)).where(
            Payment.tenant_id == tenant_id,
            Payment.shift_id == shift_id,
            Payment.method == "cash",
        )
    ).scalar_one()
    return Decimal(str(total))


def create_handover(
    db: Session,
    *,
    tenant_id: UUID,
    shift_id: UUID,
    agent_id: UUID,
    cashier_user_id: UUID,
    declared_cash_mad: Decimal,
    variance_reason: str | None,
) -> CashHandover:
    expected = expected_cash_for_shift(db, tenant_id, shift_id)
    variance = declared_cash_mad - expected
    status = "DECLARED" if variance == 0 else "VARIANCE_FLAGGED"
    ho = CashHandover(
        tenant_id=tenant_id,
        shift_id=shift_id,
        agent_id=agent_id,
        cashier_user_id=cashier_user_id,
        expected_cash_mad=expected,
        declared_cash_mad=declared_cash_mad,
        variance_mad=variance,
        variance_reason=variance_reason,
        status=status,
    )
    db.add(ho)
    db.flush()
    if variance == 0:
        db.execute(
            Payment.__table__.update()
            .where(Payment.shift_id == shift_id, Payment.tenant_id == tenant_id)
            .values(handover_status="DECLARED")
        )
    return ho
