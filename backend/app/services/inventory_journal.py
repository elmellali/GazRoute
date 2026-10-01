"""Immutable inventory movement journal. Direct balance edits are forbidden."""
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select, text as sa_text
from sqlalchemy.orm import Session

from app.core.exceptions import InsufficientStock, ValidationException
from app.models import InventoryMovement


def log_movement(
    db: Session,
    *,
    tenant_id: UUID,
    cylinder_type_id: UUID,
    cylinder_state: str,
    quantity: Decimal | float | int,
    from_location_id: UUID | None,
    to_location_id: UUID | None,
    source_type: str,
    source_id: UUID,
    created_by: UUID,
    client_event_id: UUID | None = None,
    occurred_at: datetime | None = None,
) -> InventoryMovement:
    qty = Decimal(str(quantity))
    if qty <= 0:
        raise ValidationException("quantity must be > 0")
    if cylinder_state not in ("full", "empty", "defective"):
        raise ValidationException("invalid cylinder_state")
    mv = InventoryMovement(
        tenant_id=tenant_id,
        occurred_at=occurred_at or datetime.now(timezone.utc),
        cylinder_type_id=cylinder_type_id,
        cylinder_state=cylinder_state,
        quantity=qty,
        from_location_id=from_location_id,
        to_location_id=to_location_id,
        source_type=source_type,
        source_id=source_id,
        created_by=created_by,
        client_event_id=client_event_id,
    )
    db.add(mv)
    db.flush()
    return mv


def balance_at(
    db: Session,
    *,
    tenant_id: UUID,
    location_id: UUID,
    cylinder_type_id: UUID | None = None,
    cylinder_state: str | None = None,
) -> Decimal:
    """Computed balance: SUM(to) - SUM(from) for a location."""
    if cylinder_type_id and cylinder_state:
        stmt = sa_text(
            """
            SELECT COALESCE(
                SUM(CASE WHEN to_location_id = :loc THEN quantity ELSE 0 END)
              - SUM(CASE WHEN from_location_id = :loc THEN quantity ELSE 0 END)
            , 0) AS bal
            FROM inventory_movements
            WHERE tenant_id = :tenant AND cylinder_type_id = :ctype AND cylinder_state = :cstate
            """
        )
        params = {"tenant": tenant_id, "loc": location_id, "ctype": cylinder_type_id, "cstate": cylinder_state}
    elif cylinder_type_id:
        stmt = sa_text(
            """
            SELECT COALESCE(
                SUM(CASE WHEN to_location_id = :loc THEN quantity ELSE 0 END)
              - SUM(CASE WHEN from_location_id = :loc THEN quantity ELSE 0 END)
            , 0) AS bal
            FROM inventory_movements
            WHERE tenant_id = :tenant AND cylinder_type_id = :ctype
            """
        )
        params = {"tenant": tenant_id, "loc": location_id, "ctype": cylinder_type_id}
    elif cylinder_state:
        stmt = sa_text(
            """
            SELECT COALESCE(
                SUM(CASE WHEN to_location_id = :loc THEN quantity ELSE 0 END)
              - SUM(CASE WHEN from_location_id = :loc THEN quantity ELSE 0 END)
            , 0) AS bal
            FROM inventory_movements
            WHERE tenant_id = :tenant AND cylinder_state = :cstate
            """
        )
        params = {"tenant": tenant_id, "loc": location_id, "cstate": cylinder_state}
    else:
        stmt = sa_text(
            """
            SELECT COALESCE(
                SUM(CASE WHEN to_location_id = :loc THEN quantity ELSE 0 END)
              - SUM(CASE WHEN from_location_id = :loc THEN quantity ELSE 0 END)
            , 0) AS bal
            FROM inventory_movements
            WHERE tenant_id = :tenant
            """
        )
        params = {"tenant": tenant_id, "loc": location_id}

    val = db.execute(stmt, params).scalar_one()
    return Decimal(str(val))


def assert_available(
    db: Session,
    *,
    tenant_id: UUID,
    location_id: UUID,
    cylinder_type_id: UUID,
    cylinder_state: str,
    needed: Decimal,
) -> None:
    avail = balance_at(
        db,
        tenant_id=tenant_id,
        location_id=location_id,
        cylinder_type_id=cylinder_type_id,
        cylinder_state=cylinder_state,
    )
    if avail < needed:
        raise InsufficientStock(
            f"Available {avail} {cylinder_state} cylinders at location; need {needed}"
        )


def balances_by_location(
    db: Session,
    *,
    tenant_id: UUID,
    location_ids: list[UUID],
) -> dict[tuple[UUID, UUID, str], Decimal]:
    if not location_ids:
        return {}

    stmt = (
        select(
            InventoryMovement.to_location_id.label("loc"),
            InventoryMovement.cylinder_type_id,
            InventoryMovement.cylinder_state,
            func.sum(InventoryMovement.quantity).label("in_qty"),
        )
        .where(
            InventoryMovement.tenant_id == tenant_id,
            InventoryMovement.to_location_id.in_(location_ids),
        )
        .group_by(
            InventoryMovement.to_location_id,
            InventoryMovement.cylinder_type_id,
            InventoryMovement.cylinder_state,
        )
    )
    out_stmt = (
        select(
            InventoryMovement.from_location_id.label("loc"),
            InventoryMovement.cylinder_type_id,
            InventoryMovement.cylinder_state,
            func.sum(InventoryMovement.quantity).label("out_qty"),
        )
        .where(
            InventoryMovement.tenant_id == tenant_id,
            InventoryMovement.from_location_id.in_(location_ids),
        )
        .group_by(
            InventoryMovement.from_location_id,
            InventoryMovement.cylinder_type_id,
            InventoryMovement.cylinder_state,
        )
    )

    result: dict[tuple[UUID, UUID, str], Decimal] = defaultdict(lambda: Decimal("0"))
    for row in db.execute(stmt):
        result[(row.loc, row.cylinder_type_id, row.cylinder_state)] += Decimal(str(row.in_qty))
    for row in db.execute(out_stmt):
        result[(row.loc, row.cylinder_type_id, row.cylinder_state)] -= Decimal(str(row.out_qty))
    return {k: v for k, v in result.items() if v != 0}
