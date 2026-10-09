from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select

import uuid
from pydantic import BaseModel

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
from app.repositories.base import get_tenant_scoped
from app.schemas import InventoryBalanceItem, LocationCreate, LocationOut, MovementOut
from app.services.inventory_journal import balance_at, balances_by_location, log_movement

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
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_WAREHOUSE, ROLE_DISPATCHER)),
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


@router.delete("/locations/{location_id}", status_code=204)
def delete_location(
    location_id: UUID,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_WAREHOUSE, ROLE_DISPATCHER)),
):
    loc = get_tenant_scoped(db, InventoryLocation, ctx.tenant_id, location_id, "Location not found")
    db.delete(loc)
    db.commit()
    return None


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


class FactoryReceiptLine(BaseModel):
    cylinder_type_id: UUID
    quantity: float


class FactoryReceiptIn(BaseModel):
    depot_location_id: UUID
    lines: list[FactoryReceiptLine]


@router.post("/factory-receipt", status_code=201)
def receive_from_factory(
    body: FactoryReceiptIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_WAREHOUSE, ROLE_DISPATCHER)),
):
    depot = get_tenant_scoped(db, InventoryLocation, ctx.tenant_id, body.depot_location_id, "Dépôt non trouvé")
    if depot.type != "depot":
        raise ValidationException("L'emplacement cible doit être un dépôt")
    receipt_id = uuid.uuid4()
    for line in body.lines:
        if line.quantity > 0:
            log_movement(
                db,
                tenant_id=ctx.tenant_id,
                cylinder_type_id=line.cylinder_type_id,
                cylinder_state="full",
                quantity=line.quantity,
                from_location_id=None,
                to_location_id=depot.id,
                source_type="FACTORY_RECEIPT",
                source_id=receipt_id,
                created_by=ctx.user_id,
            )
    db.commit()
    return {"status": "ok", "receipt_id": str(receipt_id)}
