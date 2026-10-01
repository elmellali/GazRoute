from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select

from app.core.deps import (
    ROLE_AUDITOR,
    ROLE_DISPATCHER,
    ROLE_OWNER,
    ROLE_WAREHOUSE,
    AuthDep,
    DbDep,
    require_roles,
)
from app.core.exceptions import NotFound, ValidationException
from app.models import InventoryLocation, InventoryMovement, Outlet
from app.schemas import InventoryBalanceItem, LocationCreate, LocationOut, MovementOut
from app.services.inventory_journal import balance_at, balances_by_location

router = APIRouter(prefix="/inventory", tags=["inventory"])


@router.get("/locations", response_model=list[LocationOut])
def list_locations(ctx: AuthDep, db: DbDep):
    rows = db.execute(
        select(InventoryLocation).where(InventoryLocation.tenant_id == ctx.tenant_id)
    ).scalars().all()
    return [LocationOut.model_validate(r) for r in rows]


@router.post("/locations", response_model=LocationOut, status_code=201)
def create_location(
    body: LocationCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_WAREHOUSE)),
):
    if body.type not in ("depot", "vehicle", "outlet", "quarantine"):
        raise ValidationException("invalid location type")
    loc = InventoryLocation(
        tenant_id=ctx.tenant_id,
        name=body.name,
        type=body.type,
        reference_id=body.reference_id,
    )
    db.add(loc)
    db.flush()
    db.commit()
    return LocationOut.model_validate(loc)


@router.get("/balances", response_model=list[InventoryBalanceItem])
def balances(ctx: AuthDep, db: DbDep, location_id: UUID | None = None):
    q = select(InventoryLocation.id).where(InventoryLocation.tenant_id == ctx.tenant_id)
    if location_id:
        q = q.where(InventoryLocation.id == location_id)
    loc_ids = list(db.execute(q).scalars().all())
    if not loc_ids:
        return []

    bal_map = balances_by_location(db, tenant_id=ctx.tenant_id, location_ids=loc_ids)
    return [
        InventoryBalanceItem(
            location_id=loc_id,
            cylinder_type_id=ct_id,
            cylinder_state=state,
            quantity=float(qty),
        )
        for (loc_id, ct_id, state), qty in sorted(
            bal_map.items(), key=lambda x: (str(x[0][0]), str(x[0][1]), x[0][2])
        )
        if qty != 0
    ]


@router.get("/movements", response_model=list[MovementOut])
def movements(
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_WAREHOUSE, ROLE_AUDITOR, ROLE_DISPATCHER)),
    limit: int = 200,
):
    rows = db.execute(
        select(InventoryMovement)
        .where(InventoryMovement.tenant_id == ctx.tenant_id)
        .order_by(InventoryMovement.occurred_at.desc())
        .limit(limit)
    ).scalars().all()
    return [MovementOut.model_validate(r) for r in rows]


@router.get("/vehicle-stock/{vehicle_id}", response_model=list[InventoryBalanceItem])
def vehicle_stock(vehicle_id: UUID, ctx: AuthDep, db: DbDep):
    loc = db.execute(
        select(InventoryLocation).where(
            InventoryLocation.tenant_id == ctx.tenant_id,
            InventoryLocation.type == "vehicle",
            InventoryLocation.reference_id == vehicle_id,
        )
    ).scalar_one_or_none()
    if loc is None:
        return []
    movements = db.execute(
        select(InventoryMovement).where(
            InventoryMovement.tenant_id == ctx.tenant_id,
            (InventoryMovement.to_location_id == loc.id)
            | (InventoryMovement.from_location_id == loc.id),
        )
    ).scalars().all()
    ctypes = {m.cylinder_type_id for m in movements}
    states = {m.cylinder_state for m in movements}
    items = []
    for ct in ctypes:
        for st in states:
            bal = balance_at(
                db,
                tenant_id=ctx.tenant_id,
                location_id=loc.id,
                cylinder_type_id=ct,
                cylinder_state=st,
            )
            if bal != 0:
                items.append(
                    InventoryBalanceItem(
                        location_id=loc.id,
                        cylinder_type_id=ct,
                        cylinder_state=st,
                        quantity=float(bal),
                    )
                )
    return items
