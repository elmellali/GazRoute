"""Credit policy: soft warning + hard aging lock."""
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import CreditOverride, DeliveryNote, Outlet, Payment


@dataclass
class CreditDecision:
    current_balance_mad: Decimal
    projected_balance_mad: Decimal
    credit_limit_mad: Decimal
    soft_warning: bool
    hard_lock: bool
    oldest_unpaid_days: int | None
    reason: str | None = None


def outlet_balance(db: Session, tenant_id: UUID, outlet_id: UUID) -> Decimal:
    dn = db.execute(
        select(func.coalesce(func.sum(DeliveryNote.total_amount_mad), 0)).where(
            DeliveryNote.tenant_id == tenant_id,
            DeliveryNote.outlet_id == outlet_id,
        )
    ).scalar_one()
    pay = db.execute(
        select(func.coalesce(func.sum(Payment.amount_mad), 0)).where(
            Payment.tenant_id == tenant_id,
            Payment.outlet_id == outlet_id,
        )
    ).scalar_one()
    return Decimal(str(dn)) - Decimal(str(pay))


def oldest_unpaid_age_days(db: Session, tenant_id: UUID, outlet_id: UUID) -> int | None:
    """Days since oldest delivery note not fully covered by payments (simplified FIFO)."""
    balance = outlet_balance(db, tenant_id, outlet_id)
    if balance <= 0:
        return None
    notes = list(
        db.execute(
            select(DeliveryNote)
            .where(DeliveryNote.tenant_id == tenant_id, DeliveryNote.outlet_id == outlet_id)
            .order_by(DeliveryNote.created_at.asc())
        ).scalars()
    )
    paid = Decimal("0")
    # payments reduce oldest first
    pays = list(
        db.execute(
            select(Payment)
            .where(Payment.tenant_id == tenant_id, Payment.outlet_id == outlet_id)
            .order_by(Payment.collected_at.asc())
        ).scalars()
    )
    for p in pays:
        paid += Decimal(str(p.amount_mad))
    remaining = paid
    oldest_open = None
    for n in notes:
        amt = Decimal(str(n.total_amount_mad))
        if remaining >= amt:
            remaining -= amt
        else:
            oldest_open = n.created_at
            break
    if oldest_open is None:
        return None
    now = datetime.now(timezone.utc)
    if oldest_open.tzinfo is None:
        oldest_open = oldest_open.replace(tzinfo=timezone.utc)
    return max(0, (now - oldest_open).days)


def active_override(db: Session, tenant_id: UUID, outlet_id: UUID, code: str) -> CreditOverride | None:
    now = datetime.now(timezone.utc)
    ov = db.execute(
        select(CreditOverride).where(
            CreditOverride.tenant_id == tenant_id,
            CreditOverride.outlet_id == outlet_id,
            CreditOverride.override_code == code,
            CreditOverride.is_active.is_(True),
            CreditOverride.used_at.is_(None),
            CreditOverride.expires_at > now,
        )
    ).scalar_one_or_none()
    return ov


def evaluate_credit(
    db: Session,
    *,
    tenant_id: UUID,
    outlet_id: UUID,
    proposed_order_total: Decimal,
    override_code: str | None = None,
) -> CreditDecision:
    outlet = db.get(Outlet, outlet_id)
    assert outlet is not None
    current = outlet_balance(db, tenant_id, outlet_id)
    limit = Decimal(str(outlet.credit_limit_mad))
    projected = current + proposed_order_total
    soft = projected > limit and limit > 0

    age_days = oldest_unpaid_age_days(db, tenant_id, outlet_id)
    hard = False
    reason = None
    if age_days is not None and age_days > settings.credit_aging_days_hard_lock:
        if override_code and active_override(db, tenant_id, outlet_id, override_code):
            hard = False
            reason = "override_accepted"
        else:
            hard = True
            reason = f"unpaid_invoice_age_{age_days}d_exceeds_{settings.credit_aging_days_hard_lock}d"

    return CreditDecision(
        current_balance_mad=current,
        projected_balance_mad=projected,
        credit_limit_mad=limit,
        soft_warning=soft,
        hard_lock=hard,
        oldest_unpaid_days=age_days,
        reason=reason,
    )
