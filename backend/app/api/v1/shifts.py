from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.deps import (
    ROLE_AGENT,
    ROLE_OWNER,
    ROLE_WAREHOUSE,
    AuthDep,
    DbDep,
    require_roles,
)
from app.core.exceptions import Conflict, Forbidden, NotFound, ValidationException
from app.models import (
    DriverShift,
    InventoryLocation,
    LoadSheet,
    LoadSheetLine,
    Payment,
    ShiftTelemetry,
    Vehicle,
)
from app.schemas import (
    AcceptLoadIn,
    CloseoutIn,
    LoadSheetCreate,
    LoadSheetOut,
    ShiftOut,
    ShiftStartIn,
    TelemetryIn,
)
from app.services.audit import write_audit
from app.services.cash import create_handover, expected_cash_for_shift
from app.services.inventory_journal import balance_at, log_movement

router = APIRouter(prefix="/shifts", tags=["shifts"])


@router.post("/start", response_model=ShiftOut, status_code=201)
def start_shift(
    body: ShiftStartIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT)),
):
    existing = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id,
            DriverShift.agent_id == ctx.user_id,
            DriverShift.status == "ACTIVE",
        )
    ).scalar_one_or_none()
    if existing:
        raise Conflict("Agent already has an active shift")

    vehicle = db.execute(
        select(Vehicle).where(
            Vehicle.tenant_id == ctx.tenant_id, Vehicle.id == body.vehicle_id
        )
    ).scalar_one_or_none()
    if vehicle is None:
        raise NotFound("Vehicle not found")

    pre = body.pre_trip_safety
    checks = [
        pre.fire_extinguisher_valid,
        pre.cargo_straps_secured,
        pre.stacking_compliant,
        pre.no_gas_leaks,
    ]
    if not all(checks):
        raise ValidationException("Pre-trip safety checklist must fully pass")

    depot = db.execute(
        select(InventoryLocation).where(
            InventoryLocation.tenant_id == ctx.tenant_id,
            InventoryLocation.type == "depot",
        )
    ).scalars().first()

    shift = DriverShift(
        tenant_id=ctx.tenant_id,
        agent_id=ctx.user_id,
        vehicle_id=body.vehicle_id,
        depot_location_id=depot.id if depot else None,
        status="ACTIVE",
        pre_trip_safety_passed=True,
        pre_trip_payload=pre.model_dump(),
        odometer_km=body.odometer_km,
        started_at=datetime.now(timezone.utc),
    )
    db.add(shift)
    db.flush()
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="shift.start",
        target_entity="driver_shifts",
        target_id=shift.id,
        after_state={"vehicle_id": str(body.vehicle_id)},
    )
    db.commit()
    return ShiftOut.model_validate(shift)


@router.get("", response_model=list[ShiftOut])
def list_shifts(ctx: AuthDep, db: DbDep, status: str | None = None, limit: int = 50):
    stmt = select(DriverShift).where(DriverShift.tenant_id == ctx.tenant_id)
    if status:
        stmt = stmt.where(DriverShift.status == status)
    shifts = db.execute(stmt.order_by(DriverShift.started_at.desc()).limit(limit)).scalars().all()
    return [ShiftOut.model_validate(s) for s in shifts]


@router.get("/me/active", response_model=ShiftOut | None)
def active_shift(ctx: AuthDep, db: DbDep):
    s = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id,
            DriverShift.agent_id == ctx.user_id,
            DriverShift.status == "ACTIVE",
        )
    ).scalar_one_or_none()
    return ShiftOut.model_validate(s) if s else None


@router.get("/{shift_id}", response_model=ShiftOut)
def get_shift(shift_id: UUID, ctx: AuthDep, db: DbDep) -> ShiftOut:
    s = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id, DriverShift.id == shift_id
        )
    ).scalar_one_or_none()
    if s is None:
        raise NotFound("Shift not found")
    if ctx.role == ROLE_AGENT and s.agent_id != ctx.user_id:
        raise Forbidden("Not your shift")
    return ShiftOut.model_validate(s)


@router.post("/{shift_id}/telemetry")
def record_telemetry(
    shift_id: UUID,
    body: TelemetryIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT)),
):
    s = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id,
            DriverShift.id == shift_id,
            DriverShift.agent_id == ctx.user_id,
        )
    ).scalar_one_or_none()
    if s is None:
        raise NotFound("Active shift not found")
    if s.status != "ACTIVE":
        raise Conflict("Shift is not active")

    now = datetime.now(timezone.utc)
    entry = ShiftTelemetry(
        tenant_id=ctx.tenant_id,
        shift_id=shift_id,
        agent_id=ctx.user_id,
        latitude=body.latitude,
        longitude=body.longitude,
        speed_kmh=body.speed_kmh,
        battery_level=body.battery_level,
        recorded_at=now,
    )
    db.add(entry)
    db.commit()
    return {"status": "ok", "recorded_at": now.isoformat()}



def _vehicle_location(db: Session, tenant_id: UUID, vehicle_id: UUID) -> InventoryLocation:
    loc = db.execute(
        select(InventoryLocation).where(
            InventoryLocation.tenant_id == tenant_id,
            InventoryLocation.type == "vehicle",
            InventoryLocation.reference_id == vehicle_id,
        )
    ).scalar_one_or_none()
    if loc is None:
        loc = InventoryLocation(
            tenant_id=tenant_id,
            name=f"Vehicle {vehicle_id}",
            type="vehicle",
            reference_id=vehicle_id,
        )
        db.add(loc)
        db.flush()
    return loc


@router.post("/load-sheets", response_model=LoadSheetOut, status_code=201)
def create_load_sheet(
    body: LoadSheetCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_WAREHOUSE, ROLE_OWNER)),
):
    vehicle = db.execute(
        select(Vehicle).where(Vehicle.tenant_id == ctx.tenant_id, Vehicle.id == body.vehicle_id)
    ).scalar_one_or_none()
    if vehicle is None:
        raise NotFound("Vehicle not found")
    ls = LoadSheet(
        tenant_id=ctx.tenant_id,
        shift_id=body.shift_id,
        vehicle_id=body.vehicle_id,
        depot_location_id=body.depot_location_id,
        warehouse_user_id=ctx.user_id,
        status="PENDING_ACCEPT",
    )
    db.add(ls)
    db.flush()
    for line in body.lines:
        db.add(
            LoadSheetLine(
                load_sheet_id=ls.id,
                cylinder_type_id=line.cylinder_type_id,
                quantity=line.quantity,
            )
        )
    db.flush()
    db.commit()
    return LoadSheetOut.model_validate(ls)


@router.get("/load-sheets", response_model=list[LoadSheetOut])
def list_load_sheets(
    ctx: AuthDep,
    db: DbDep,
    limit: int = 50,
) -> list[LoadSheetOut]:
    rows = (
        db.execute(
            select(LoadSheet)
            .where(LoadSheet.tenant_id == ctx.tenant_id)
            .order_by(LoadSheet.created_at.desc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    return [LoadSheetOut.model_validate(r) for r in rows]


@router.post("/{shift_id}/accept-load", response_model=dict, status_code=201)
def accept_load(
    shift_id: UUID,
    body: AcceptLoadIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT)),
):
    shift = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id, DriverShift.id == shift_id
        )
    ).scalar_one_or_none()
    if shift is None:
        raise NotFound("Shift not found")
    if shift.agent_id != ctx.user_id:
        raise Forbidden("Not your shift")
    if shift.status != "ACTIVE":
        raise Conflict("Shift is not active")

    ls = db.execute(
        select(LoadSheet).where(
            LoadSheet.tenant_id == ctx.tenant_id, LoadSheet.id == body.load_sheet_id
        )
    ).scalar_one_or_none()
    if ls is None:
        raise NotFound("Load sheet not found")
    if ls.status != "PENDING_ACCEPT":
        raise Conflict("Load sheet already processed")

    vehicle_loc = _vehicle_location(db, ctx.tenant_id, shift.vehicle_id)
    accepted = {str(line.cylinder_type_id): Decimal(str(line.quantity)) for line in body.accepted_quantities}
    planned = {
        str(line.cylinder_type_id): Decimal(str(line.quantity))
        for line in db.execute(
            select(LoadSheetLine).where(LoadSheetLine.load_sheet_id == ls.id)
        ).scalars()
    }
    # Agent may accept <= planned quantities
    movements = 0
    for ctid, qty in accepted.items():
        if qty <= 0:
            raise ValidationException("quantity must be > 0")
        planned_qty = planned.get(UUID(ctid) if isinstance(ctid, str) else ctid, None)
        # planned keys are str of uuid
        planned_qty = planned.get(ctid)
        if planned_qty is None:
            raise ValidationException(f"cylinder_type {ctid} not on load sheet")
        if qty > planned_qty:
            raise ValidationException("accepted quantity exceeds load sheet")
        from uuid import UUID as _UUID

        log_movement(
            db,
            tenant_id=ctx.tenant_id,
            cylinder_type_id=_UUID(ctid),
            cylinder_state="full",
            quantity=qty,
            from_location_id=ls.depot_location_id,
            to_location_id=vehicle_loc.id,
            source_type="LOAD_SHEET",
            source_id=ls.id,
            created_by=ctx.user_id,
            client_event_id=shift_id,  # unique-ish per shift accept; better client event
        )
        movements += 1

    ls.status = "ACCEPTED"
    ls.shift_id = shift.id
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="load.accept",
        target_entity="load_sheets",
        target_id=ls.id,
        after_state={"movements": movements},
    )
    db.commit()
    return {
        "status": "accepted",
        "load_sheet_id": str(ls.id),
        "movements_logged": movements,
        "vehicle_location_id": str(vehicle_loc.id),
    }


@router.post("/{shift_id}/closeout-unload", response_model=dict)
def closeout_unload(
    shift_id: UUID,
    body: CloseoutIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT, ROLE_WAREHOUSE)),
):
    shift = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id, DriverShift.id == shift_id
        )
    ).scalar_one_or_none()
    if shift is None:
        raise NotFound("Shift not found")
    if shift.status in ("CLOSED", "RECONCILED"):
        raise Conflict("Shift already closed")

    vehicle_loc = _vehicle_location(db, ctx.tenant_id, shift.vehicle_id)
    depot_id = shift.depot_location_id
    if depot_id is None:
        depot = db.execute(
            select(InventoryLocation).where(
                InventoryLocation.tenant_id == ctx.tenant_id,
                InventoryLocation.type == "depot",
            )
        ).scalars().first()
        if depot is None:
            raise ValidationException("No depot location configured")
        depot_id = depot.id

    quarantine = db.execute(
        select(InventoryLocation).where(
            InventoryLocation.tenant_id == ctx.tenant_id,
            InventoryLocation.type == "quarantine",
        )
    ).scalars().first()
    if quarantine is None:
        quarantine = InventoryLocation(
            tenant_id=ctx.tenant_id, name="Quarantine", type="quarantine"
        )
        db.add(quarantine)
        db.flush()

    movements = 0
    for line in body.unloaded_lines:
        state = line.state
        if state not in ("full", "empty", "defective"):
            raise ValidationException("invalid state")
        qty = Decimal(str(line.quantity))
        if qty <= 0:
            raise ValidationException("quantity must be > 0")
        # verify availability on vehicle
        avail = balance_at(
            db,
            tenant_id=ctx.tenant_id,
            location_id=vehicle_loc.id,
            cylinder_type_id=line.cylinder_type_id,
            cylinder_state=state,
        )
        if avail < qty:
            raise Conflict(
                f"Vehicle has {avail} {state} for {line.cylinder_type_id}, cannot unload {qty}"
            )
        dest = quarantine.id if state == "defective" else depot_id
        log_movement(
            db,
            tenant_id=ctx.tenant_id,
            cylinder_type_id=line.cylinder_type_id,
            cylinder_state=state,
            quantity=qty,
            from_location_id=vehicle_loc.id,
            to_location_id=dest,
            source_type="DEPOT_UNLOAD",
            source_id=shift.id,
            created_by=ctx.user_id,
        )
        movements += 1

    # Verify vehicle empty of commercial stock
    from app.models import InventoryMovement
    from sqlalchemy import func

    remaining = db.execute(
        select(func.coalesce(func.sum(InventoryMovement.quantity), 0)).where(
            InventoryMovement.tenant_id == ctx.tenant_id,
            (InventoryMovement.to_location_id == vehicle_loc.id)
            | (InventoryMovement.from_location_id == vehicle_loc.id),
        )
    ).scalar_one()
    # compute net for vehicle
    net_in = db.execute(
        select(func.coalesce(func.sum(InventoryMovement.quantity), 0)).where(
            InventoryMovement.tenant_id == ctx.tenant_id,
            InventoryMovement.to_location_id == vehicle_loc.id,
        )
    ).scalar_one()
    net_out = db.execute(
        select(func.coalesce(func.sum(InventoryMovement.quantity), 0)).where(
            InventoryMovement.tenant_id == ctx.tenant_id,
            InventoryMovement.from_location_id == vehicle_loc.id,
        )
    ).scalar_one()
    vehicle_net = Decimal(str(net_in)) - Decimal(str(net_out))
    if vehicle_net != 0:
        raise Conflict(
            f"Vehicle stock must be zero before closeout (remaining net={vehicle_net}). "
            "Document variance via notes if physical count differs."
        )

    declared = Decimal(str(body.declared_cash_mad))
    expected = expected_cash_for_shift(db, ctx.tenant_id, shift.id)
    handover = create_handover(
        db,
        tenant_id=ctx.tenant_id,
        shift_id=shift.id,
        agent_id=shift.agent_id,
        cashier_user_id=body.cashier_user_id,
        declared_cash_mad=declared,
        variance_reason=body.variance_reason,
    )

    shift.ended_at = datetime.now(timezone.utc)
    shift.declared_cash_mad = declared
    shift.status = "VARIANCE_FLAGGED" if handover.variance_mad != 0 else "RECONCILED"

    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="shift.closeout",
        target_entity="driver_shifts",
        target_id=shift.id,
        after_state={
            "movements": movements,
            "declared_cash_mad": float(declared),
            "expected_cash_mad": float(expected),
            "variance_mad": float(handover.variance_mad or 0),
        },
    )
    db.commit()
    return {
        "status": shift.status,
        "movements_logged": movements,
        "handover_id": str(handover.id),
        "expected_cash_mad": float(expected),
        "declared_cash_mad": float(declared),
        "variance_mad": float(handover.variance_mad or 0),
    }
