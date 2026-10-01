from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select

from app.core.deps import ROLE_ACCOUNTANT, ROLE_AGENT, AuthDep, DbDep, IdempotencyKey, require_roles
from app.core.exceptions import Conflict, CreditLocked, Forbidden, NotFound, ValidationException
from app.core.idempotency import get_replay, payload_hash, save_replay
from app.models import CylinderType, DeliveryNote, DeliveryNoteLine, DriverShift, InventoryLocation, Outlet, Payment, Route, RouteStop, User
from app.schemas import DeliveryIn, DeliveryOut, PaymentCreate, PaymentOut
from app.services.audit import write_audit
from app.services.cash import next_delivery_receipt, next_payment_receipt
from app.services.credit import evaluate_credit, outlet_balance
from app.services.inventory_journal import assert_available, balance_at, log_movement
from app.services.pricing import quote_line
from app.api.v1.shifts import _vehicle_location

router = APIRouter(tags=["field-execution"])


def _stop_owned(db, ctx, stop: RouteStop) -> None:
    route = db.get(Route, stop.route_id)
    if route is None:
        raise NotFound("Route not found")
    if ctx.role == ROLE_AGENT:
        shift = db.get(DriverShift, route.shift_id)
        if shift is None or shift.agent_id != ctx.user_id:
            raise Forbidden("Stop not assigned to this agent")


@router.post(
    "/route-stops/{stop_id}/deliveries",
    response_model=DeliveryOut,
    status_code=201,
)
def create_delivery(
    stop_id: UUID,
    body: DeliveryIn,
    ctx: AuthDep,
    db: DbDep,
    idem_key: IdempotencyKey,
    _guard=Depends(require_roles(ROLE_AGENT)),
):
    if not idem_key:
        raise ValidationException("Idempotency-Key header required")

    request_hash = payload_hash(body.model_dump())
    replay = get_replay(db, tenant_id=ctx.tenant_id, key=idem_key, request_hash=request_hash)
    if replay is not None and replay.response_status == 201:
        data = replay.response_body
        return DeliveryOut(**data)

    stop = db.execute(
        select(RouteStop).where(RouteStop.tenant_id == ctx.tenant_id, RouteStop.id == stop_id)
    ).scalar_one_or_none()
    if stop is None:
        raise NotFound("Route stop not found")
    _stop_owned(db, ctx, stop)
    if stop.status in ("PENDING", "EN_ROUTE", "NEARBY"):
        raise Conflict("Check in before delivering")
    if stop.status in ("COMPLETED", "EXCEPTION"):
        raise Conflict("Stop already finalized")

    outlet = db.get(Outlet, stop.outlet_id)
    if outlet is None or not outlet.is_active:
        raise ValidationException("Outlet inactive")

    route = db.get(Route, stop.route_id)
    assert route is not None
    shift = db.get(DriverShift, route.shift_id)
    if shift is None:
        raise ValidationException("Shift missing for route")

    vehicle_loc = _vehicle_location(db, ctx.tenant_id, shift.vehicle_id)
    outlet_locs = db.execute(
        select(InventoryLocation).where(
            InventoryLocation.tenant_id == ctx.tenant_id,
            InventoryLocation.type == "outlet",
            InventoryLocation.reference_id == outlet.id,
        )
    ).scalars().first()

    if outlet_locs is None:
        outlet_locs = InventoryLocation(
            tenant_id=ctx.tenant_id,
            name=outlet.name,
            type="outlet",
            reference_id=outlet.id,
        )
        db.add(outlet_locs)
        db.flush()

    if not body.lines:
        raise ValidationException("Delivery requires at least one line")

    # Price all lines first for credit check
    quotes = []
    total_due = Decimal("0")
    deposit_net_total = Decimal("0")
    subtotal_total = Decimal("0")
    for line in body.lines:
        ct = db.execute(
            select(CylinderType).where(
                CylinderType.tenant_id == ctx.tenant_id,
                CylinderType.id == line.cylinder_type_id,
            )
        ).scalar_one_or_none()
        if ct is None:
            raise NotFound("Cylinder type not found")
        delivered = Decimal(str(line.delivered_full_qty))
        returned = Decimal(str(line.returned_empty_qty))
        defective = Decimal(str(line.returned_defective_qty))
        if delivered < 0 or returned < 0 or defective < 0:
            raise ValidationException("quantities must be >= 0")
        q = quote_line(
            base_price=Decimal(str(ct.base_sale_price_mad)),
            deposit_rate=Decimal(str(ct.deposit_amount_mad)),
            delivered_qty=delivered,
            returned_qty=returned + defective,
            price_override=Decimal(str(line.price_override_mad)),
            discount=Decimal(str(line.discount_mad)),
        )
        quotes.append((line, ct, q, delivered, returned, defective))
        subtotal_total += q.line_subtotal_mad
        deposit_net_total += q.deposit_net_impact_mad
        total_due += q.total_invoice_mad

    # Stock checks on vehicle
    for line, ct, q, delivered, returned, defective in quotes:
        if delivered > 0:
            assert_available(
                db,
                tenant_id=ctx.tenant_id,
                location_id=vehicle_loc.id,
                cylinder_type_id=ct.id,
                cylinder_state="full",
                needed=delivered,
            )

    # Credit check
    proposed = total_due
    if body.payment:
        proposed = total_due - Decimal(str(body.payment.amount_mad))
        if proposed < 0:
            proposed = Decimal("0")
    credit = evaluate_credit(
        db,
        tenant_id=ctx.tenant_id,
        outlet_id=outlet.id,
        proposed_order_total=max(proposed, Decimal("0")),
        override_code=body.override_code,
    )
    if credit.hard_lock:
        write_audit(
            db,
            tenant_id=ctx.tenant_id,
            actor_id=ctx.user_id,
            action="credit.hard_lock_block",
            target_entity="outlets",
            target_id=outlet.id,
            after_state={"reason": credit.reason},
        )
        db.commit()
        raise CreditLocked(
            f"Hard credit lock: {credit.reason}. Manager override code required."
        )

    try:
        occurred = datetime.fromisoformat(body.occurred_at.replace("Z", "+00:00"))
    except ValueError:
        raise ValidationException("occurred_at must be ISO8601")

    receipt = next_delivery_receipt(db, ctx.tenant_id, occurred)
    note = DeliveryNote(
        tenant_id=ctx.tenant_id,
        route_stop_id=stop.id,
        outlet_id=outlet.id,
        shift_id=shift.id,
        agent_id=ctx.user_id,
        receipt_number=receipt,
        recipient_name=body.recipient_name,
        signature_media_token=body.signature_media_token,
        photo_media_token=body.photo_media_token,
        subtotal_mad=subtotal_total,
        deposit_net_mad=deposit_net_total,
        total_amount_mad=total_due,
        client_event_id=body.client_event_id,
        created_at=occurred,
    )
    db.add(note)
    db.flush()

    movements = 0
    for line, ct, q, delivered, returned, defective in quotes:
        db.add(
            DeliveryNoteLine(
                delivery_note_id=note.id,
                cylinder_type_id=ct.id,
                delivered_full_qty=delivered,
                returned_empty_qty=returned,
                returned_defective_qty=defective,
                applied_unit_price_mad=q.applied_unit_price_mad,
                applied_deposit_rate_mad=q.applied_deposit_rate_mad,
                line_total_mad=q.line_subtotal_mad + q.deposit_net_impact_mad,
            )
        )
        if delivered > 0:
            log_movement(
                db,
                tenant_id=ctx.tenant_id,
                cylinder_type_id=ct.id,
                cylinder_state="full",
                quantity=delivered,
                from_location_id=vehicle_loc.id,
                to_location_id=outlet_locs.id,
                source_type="DELIVERY",
                source_id=note.id,
                created_by=ctx.user_id,
                client_event_id=body.client_event_id,
                occurred_at=occurred,
            )
            movements += 1
        if returned > 0:
            log_movement(
                db,
                tenant_id=ctx.tenant_id,
                cylinder_type_id=ct.id,
                cylinder_state="empty",
                quantity=returned,
                from_location_id=outlet_locs.id,
                to_location_id=vehicle_loc.id,
                source_type="RETURN",
                source_id=note.id,
                created_by=ctx.user_id,
                occurred_at=occurred,
            )
            movements += 1
        if defective > 0:
            # outlet -> vehicle as empty-like defective, then vehicle quarantine handled at unload;
            # log as defective from outlet to vehicle
            log_movement(
                db,
                tenant_id=ctx.tenant_id,
                cylinder_type_id=ct.id,
                cylinder_state="defective",
                quantity=defective,
                from_location_id=outlet_locs.id,
                to_location_id=vehicle_loc.id,
                source_type="RETURN",
                source_id=note.id,
                created_by=ctx.user_id,
                occurred_at=occurred,
            )
            movements += 1

    paid = Decimal("0")
    if body.payment is not None:
        if body.payment.amount_mad <= 0:
            raise ValidationException("payment amount must be > 0")
        if body.payment.method not in ("cash", "check", "bank_transfer", "mobile_wallet"):
            raise ValidationException("invalid payment method")
        pay_receipt = next_payment_receipt(db, ctx.tenant_id, occurred)
        import uuid as uuid_mod

        payment = Payment(
            tenant_id=ctx.tenant_id,
            outlet_id=outlet.id,
            route_stop_id=stop.id,
            agent_id=ctx.user_id,
            amount_mad=Decimal(str(body.payment.amount_mad)),
            method=body.payment.method,
            reference=body.payment.reference,
            receipt_number=pay_receipt,
            collected_at=occurred,
            shift_id=shift.id,
            client_event_id=uuid_mod.uuid5(uuid_mod.NAMESPACE_URL, f"pay:{body.client_event_id}"),
            handover_status="COLLECTED",
        )
        db.add(payment)
        db.flush()
        paid = Decimal(str(body.payment.amount_mad))

    # Finalize stop
    stop.status = "COMPLETED"
    stop.completed_at = occurred
    route = db.get(Route, stop.route_id)
    if route is not None:
        stops = db.execute(
            select(RouteStop).where(RouteStop.route_id == route.id)
        ).scalars().all()
        if all(s.status in ("COMPLETED", "EXCEPTION") for s in stops):
            route.status = "COMPLETED"

    remaining = outlet_balance(db, ctx.tenant_id, outlet.id)

    response = DeliveryOut(
        delivery_note_id=note.id,
        receipt_number=receipt,
        total_amount_mad=float(total_due),
        subtotal_mad=float(subtotal_total),
        deposit_net_mad=float(deposit_net_total),
        paid_amount_mad=float(paid),
        remaining_outlet_balance_mad=float(remaining),
        movements_logged=movements,
        credit_soft_warning=credit.soft_warning,
    )

    save_replay(
        db,
        tenant_id=ctx.tenant_id,
        key=idem_key,
        request_hash=request_hash,
        response_status=201,
        response_body=response.model_dump(mode="json"),
    )
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="delivery.create",
        target_entity="delivery_notes",
        target_id=note.id,
        after_state={"receipt_number": receipt, "total": float(total_due), "paid": float(paid)},
    )
    db.commit()
    return response


@router.get("/delivery-notes", response_model=list[dict])
def list_delivery_notes(ctx: AuthDep, db: DbDep, limit: int = 50):
    rows = db.execute(
        select(DeliveryNote)
        .where(DeliveryNote.tenant_id == ctx.tenant_id)
        .order_by(DeliveryNote.created_at.desc())
        .limit(limit)
    ).scalars().all()
    return [
        {
            "id": str(r.id),
            "receipt_number": r.receipt_number,
            "outlet_id": str(r.outlet_id),
            "recipient_name": r.recipient_name,
            "total_amount_mad": float(r.total_amount_mad),
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


@router.get("/delivery-notes/{note_id}", response_model=dict)
def get_delivery_note(note_id: UUID, ctx: AuthDep, db: DbDep):
    note = db.execute(
        select(DeliveryNote).where(
            DeliveryNote.tenant_id == ctx.tenant_id, DeliveryNote.id == note_id
        )
    ).scalar_one_or_none()
    if note is None:
        raise NotFound("Delivery note not found")
    lines = db.execute(
        select(DeliveryNoteLine).where(DeliveryNoteLine.delivery_note_id == note.id)
    ).scalars().all()
    return {
        "id": str(note.id),
        "receipt_number": note.receipt_number,
        "outlet_id": str(note.outlet_id),
        "recipient_name": note.recipient_name,
        "subtotal_mad": float(note.subtotal_mad),
        "deposit_net_mad": float(note.deposit_net_mad),
        "total_amount_mad": float(note.total_amount_mad),
        "signature_media_token": note.signature_media_token,
        "photo_media_token": note.photo_media_token,
        "lines": [
            {
                "cylinder_type_id": str(l.cylinder_type_id),
                "delivered_full_qty": float(l.delivered_full_qty),
                "returned_empty_qty": float(l.returned_empty_qty),
                "returned_defective_qty": float(l.returned_defective_qty),
                "applied_unit_price_mad": float(l.applied_unit_price_mad),
                "line_total_mad": float(l.line_total_mad),
            }
            for l in lines
        ],
    }


@router.post("/payments", response_model=PaymentOut, status_code=201)
def create_payment(
    body: PaymentCreate,
    ctx: AuthDep,
    db: DbDep,
    idem_key: IdempotencyKey,
    _guard=Depends(require_roles(ROLE_AGENT, ROLE_ACCOUNTANT)),
):
    if not idem_key:
        raise ValidationException("Idempotency-Key header required")
    request_hash = payload_hash(body.model_dump())
    replay = get_replay(db, tenant_id=ctx.tenant_id, key=idem_key, request_hash=request_hash)
    if replay is not None and replay.response_status == 201:
        return PaymentOut(**replay.response_body)

    outlet = db.execute(
        select(Outlet).where(Outlet.tenant_id == ctx.tenant_id, Outlet.id == body.outlet_id)
    ).scalar_one_or_none()
    if outlet is None:
        raise NotFound("Outlet not found")
    if body.amount_mad <= 0:
        raise ValidationException("amount_mad must be > 0")
    if body.method not in ("cash", "check", "bank_transfer", "mobile_wallet"):
        raise ValidationException("invalid method")

    if body.collected_at:
        try:
            collected = datetime.fromisoformat(body.collected_at.replace("Z", "+00:00"))
        except ValueError:
            raise ValidationException("collected_at must be ISO8601")
    else:
        collected = datetime.now(timezone.utc)

    receipt = next_payment_receipt(db, ctx.tenant_id, collected)
    payment = Payment(
        tenant_id=ctx.tenant_id,
        outlet_id=body.outlet_id,
        route_stop_id=body.route_stop_id,
        agent_id=ctx.user_id,
        amount_mad=Decimal(str(body.amount_mad)),
        method=body.method,
        reference=body.reference,
        receipt_number=receipt,
        collected_at=collected,
        client_event_id=body.client_event_id,
        handover_status="COLLECTED",
    )
    db.add(payment)
    db.flush()
    out = PaymentOut.model_validate(payment)
    save_replay(
        db,
        tenant_id=ctx.tenant_id,
        key=idem_key,
        request_hash=request_hash,
        response_status=201,
        response_body=out.model_dump(mode="json"),
    )
    db.commit()
    return out


@router.get("/payments", response_model=list[PaymentOut])
def list_payments(ctx: AuthDep, db: DbDep, limit: int = 100):
    rows = db.execute(
        select(Payment)
        .where(Payment.tenant_id == ctx.tenant_id)
        .order_by(Payment.collected_at.desc())
        .limit(limit)
    ).scalars().all()
    return [PaymentOut.model_validate(r) for r in rows]


@router.get("/outlets/{outlet_id}/balance", response_model=dict)
def get_balance(outlet_id: UUID, ctx: AuthDep, db: DbDep):
    outlet = db.execute(
        select(Outlet).where(Outlet.tenant_id == ctx.tenant_id, Outlet.id == outlet_id)
    ).scalar_one_or_none()
    if outlet is None:
        raise NotFound("Outlet not found")
    bal = outlet_balance(db, ctx.tenant_id, outlet_id)
    return {
        "outlet_id": str(outlet_id),
        "balance_mad": float(bal),
        "credit_limit_mad": float(outlet.credit_limit_mad),
    }


def _delivery_note_to_pdf(db, tenant_id: UUID, note: DeliveryNote) -> bytes:
    from app.models import Tenant, User, Outlet, CylinderType
    from app.services.pdf_bl import generate_delivery_note_pdf
    from app.services.credit import outlet_balance

    tenant = db.get(Tenant, tenant_id)
    outlet = db.get(Outlet, note.outlet_id)
    agent = db.get(User, note.agent_id) if note.agent_id else None

    db_lines = db.execute(
        select(DeliveryNoteLine).where(DeliveryNoteLine.delivery_note_id == note.id)
    ).scalars().all()

    formatted_lines = []
    for l in db_lines:
        ct = db.get(CylinderType, l.cylinder_type_id)
        c_name = f"{ct.gas_type.capitalize()} {ct.size_kg:.0f}kg" if ct else "Bouteille GPL"
        formatted_lines.append({
            "name": c_name,
            "delivered": float(l.delivered_full_qty),
            "returned": float(l.returned_empty_qty),
            "defective": float(l.returned_defective_qty),
            "unit_price": float(l.applied_unit_price_mad),
            "line_total": float(l.line_total_mad),
        })

    payment = db.execute(
        select(Payment).where(
            Payment.tenant_id == tenant_id,
            Payment.route_stop_id == note.route_stop_id,
        )
    ).scalars().first()
    paid_mad = float(payment.amount_mad) if payment else 0.0
    cur_bal = outlet_balance(db, tenant_id, note.outlet_id)

    return generate_delivery_note_pdf(
        tenant_name=tenant.company_name if tenant else "Gaz Distribution",
        tenant_phone=tenant.phone if tenant else "",
        tenant_ice=tenant.ice_number if tenant else None,
        receipt_number=note.receipt_number,
        delivery_date=note.created_at,
        outlet_name=outlet.name if outlet else "Client",
        outlet_phone=outlet.phone if outlet else "",
        recipient_name=note.recipient_name,
        agent_name=agent.full_name if agent else "Chauffeur",
        lines=formatted_lines,
        subtotal_mad=note.subtotal_mad,
        deposit_net_mad=note.deposit_net_mad,
        total_amount_mad=note.total_amount_mad,
        paid_amount_mad=paid_mad,
        remaining_balance_mad=float(cur_bal),
        signature_base64=note.signature_media_token,
    )


@router.get("/delivery-notes/{delivery_note_id}/pdf")
def get_delivery_note_pdf(delivery_note_id: UUID, ctx: AuthDep, db: DbDep):
    note = db.execute(
        select(DeliveryNote).where(
            DeliveryNote.tenant_id == ctx.tenant_id,
            DeliveryNote.id == delivery_note_id,
        )
    ).scalar_one_or_none()
    if note is None:
        raise NotFound("Delivery note not found")
    pdf_bytes = _delivery_note_to_pdf(db, ctx.tenant_id, note)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename={note.receipt_number}.pdf"},
    )


@router.get("/route-stops/{stop_id}/delivery-note/pdf")
def get_stop_delivery_note_pdf(stop_id: UUID, ctx: AuthDep, db: DbDep):
    note = db.execute(
        select(DeliveryNote).where(
            DeliveryNote.tenant_id == ctx.tenant_id,
            DeliveryNote.route_stop_id == stop_id,
        )
    ).scalars().first()
    if note is None:
        raise NotFound("No delivery note for this stop")
    pdf_bytes = _delivery_note_to_pdf(db, ctx.tenant_id, note)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename={note.receipt_number}.pdf"},
    )

