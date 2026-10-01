from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select

from app.core.deps import ROLE_AGENT, ROLE_DISPATCHER, ROLE_OWNER, AuthDep, DbDep, require_roles
from app.core.exceptions import NotFound
from app.models import Outlet
from app.schemas import CreditCheckIn, CreditCheckOut
from app.services.credit import evaluate_credit, outlet_balance

router = APIRouter(prefix="/credit", tags=["credit"])


@router.post("/outlets/{outlet_id}/check", response_model=CreditCheckOut)
def credit_check(
    outlet_id: UUID,
    body: CreditCheckIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT, ROLE_DISPATCHER, ROLE_OWNER)),
):
    outlet = db.execute(
        select(Outlet).where(Outlet.tenant_id == ctx.tenant_id, Outlet.id == outlet_id)
    ).scalar_one_or_none()
    if outlet is None:
        raise NotFound("Outlet not found")
    from decimal import Decimal

    decision = evaluate_credit(
        db,
        tenant_id=ctx.tenant_id,
        outlet_id=outlet_id,
        proposed_order_total=Decimal(str(body.proposed_order_total_mad)),
        override_code=body.override_code,
    )
    return CreditCheckOut(
        current_balance_mad=float(decision.current_balance_mad),
        projected_balance_mad=float(decision.projected_balance_mad),
        credit_limit_mad=float(decision.credit_limit_mad),
        soft_warning=decision.soft_warning,
        hard_lock=decision.hard_lock,
        oldest_unpaid_days=decision.oldest_unpaid_days,
        reason=decision.reason,
    )


@router.get("/outlets/{outlet_id}/balance", response_model=dict)
def balance(outlet_id: UUID, ctx: AuthDep, db: DbDep):
    outlet = db.execute(
        select(Outlet).where(Outlet.tenant_id == ctx.tenant_id, Outlet.id == outlet_id)
    ).scalar_one_or_none()
    if outlet is None:
        raise NotFound("Outlet not found")
    bal = outlet_balance(db, ctx.tenant_id, outlet_id)
    return {"outlet_id": str(outlet_id), "balance_mad": float(bal)}
