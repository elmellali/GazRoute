from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, Query, UploadFile, File
from sqlalchemy import select

from app.core.deps import (
    ROLE_ACCOUNTANT,
    ROLE_AGENT,
    ROLE_AUDITOR,
    ROLE_DISPATCHER,
    ROLE_OWNER,
    ROLE_WAREHOUSE,
    AuthDep,
    DbDep,
    require_roles,
)
from app.core.exceptions import Forbidden, NotFound, ValidationException
from app.models import (
    CashHandover,
    CreditOverride,
    DriverShift,
    Payment,
    Route,
    RouteStop,
    SafetyIncident,
    ShiftTelemetry,
    User,
    Vehicle,
)
from app.schemas import (
    HandoverOut,
    HandoverVerifyIn,
    LiveFleetVehicleOut,
    OverviewOut,
    OverrideCreate,
    OverrideOut,
    PaymentOut,
    SafetyIn,
    SafetyOut,
)
from app.services.audit import write_audit
from app.services.media import create_upload_token, presign_download, write_media

router = APIRouter(tags=["ops"])


# ---- Safety ----
@router.post("/safety-incidents", response_model=SafetyOut, status_code=201)
def report_safety(
    body: SafetyIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT, ROLE_WAREHOUSE, ROLE_DISPATCHER, ROLE_OWNER)),
):
    shift = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id, DriverShift.id == body.shift_id
        )
    ).scalar_one_or_none()
    if shift is None:
        raise NotFound("Shift not found")
    if body.severity not in ("LOW", "HIGH", "CRITICAL"):
        raise ValidationException("invalid severity")

    location = None
    if body.latitude is not None and body.longitude is not None:
        from geoalchemy2.elements import WKTElement

        location = WKTElement(f"POINT({body.longitude} {body.latitude})", srid=4326)

    inc = SafetyIncident(
        tenant_id=ctx.tenant_id,
        shift_id=body.shift_id,
        reported_by=ctx.user_id,
        incident_type=body.incident_type,
        severity=body.severity,
        description=body.description,
        location=location,
        photo_media_token=body.photo_media_token,
        cylinder_type_id=body.cylinder_type_id,
    )
    db.add(inc)
    db.flush()
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="safety.report",
        target_entity="safety_incidents",
        target_id=inc.id,
        after_state={"severity": body.severity, "type": body.incident_type},
    )
    db.commit()
    if body.severity == "CRITICAL":
        # SMS/push stub
        print(f"[ALERT STUB] CRITICAL safety incident {inc.id}: {body.description}")
    return SafetyOut.model_validate(inc)


@router.get("/safety-incidents", response_model=list[SafetyOut])
def list_safety(ctx: AuthDep, db: DbDep, limit: int = 100):
    rows = db.execute(
        select(SafetyIncident)
        .where(SafetyIncident.tenant_id == ctx.tenant_id)
        .order_by(SafetyIncident.created_at.desc())
        .limit(limit)
    ).scalars().all()
    return [SafetyOut.model_validate(r) for r in rows]


@router.post("/safety-incidents/{incident_id}/resolve", response_model=SafetyOut)
def resolve_safety(
    incident_id: UUID,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_DISPATCHER, ROLE_WAREHOUSE)),
):
    inc = db.execute(
        select(SafetyIncident).where(
            SafetyIncident.tenant_id == ctx.tenant_id, SafetyIncident.id == incident_id
        )
    ).scalar_one_or_none()
    if inc is None:
        raise NotFound("Incident not found")
    inc.is_resolved = True
    inc.resolved_by = ctx.user_id
    db.commit()
    return SafetyOut.model_validate(inc)


# ---- Cash handover desk ----
@router.get("/handovers", response_model=list[HandoverOut])
def list_handovers(
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_ACCOUNTANT, ROLE_OWNER, ROLE_AUDITOR, ROLE_DISPATCHER)),
    limit: int = 100,
):
    rows = db.execute(
        select(CashHandover)
        .where(CashHandover.tenant_id == ctx.tenant_id)
        .order_by(CashHandover.created_at.desc())
        .limit(limit)
    ).scalars().all()
    return [HandoverOut.model_validate(r) for r in rows]


@router.post("/handovers/{handover_id}/verify", response_model=HandoverOut)
def verify_handover(
    handover_id: UUID,
    body: HandoverVerifyIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_ACCOUNTANT, ROLE_OWNER)),
):
    ho = db.execute(
        select(CashHandover).where(
            CashHandover.tenant_id == ctx.tenant_id, CashHandover.id == handover_id
        )
    ).scalar_one_or_none()
    if ho is None:
        raise NotFound("Handover not found")
    verified = Decimal(str(body.verified_cash_mad))
    variance = verified - ho.declared_cash_mad
    ho.verified_cash_mad = verified
    ho.variance_mad = verified - ho.expected_cash_mad
    if body.variance_reason:
        ho.variance_reason = body.variance_reason
    ho.status = "VERIFIED" if variance == 0 else "VARIANCE_FLAGGED"
    if variance == 0 and ho.declared_cash_mad == ho.expected_cash_mad:
        db.execute(
            Payment.__table__.update()
            .where(Payment.shift_id == ho.shift_id, Payment.tenant_id == ctx.tenant_id)
            .values(handover_status="VERIFIED")
        )
    elif variance != 0 and not body.variance_reason:
        raise ValidationException("variance_reason required when counts differ")
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="handover.verify",
        target_entity="cash_handovers",
        target_id=ho.id,
        after_state={
            "verified": float(verified),
            "variance": float(ho.variance_mad or 0),
            "status": ho.status,
        },
    )
    db.commit()
    return HandoverOut.model_validate(ho)


# ---- Credit overrides ----
@router.post("/credit-overrides", response_model=OverrideOut, status_code=201)
def create_override(
    body: OverrideCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_DISPATCHER)),
):
    import secrets

    code = secrets.token_urlsafe(12)
    ov = CreditOverride(
        tenant_id=ctx.tenant_id,
        outlet_id=body.outlet_id,
        issued_by=ctx.user_id,
        override_code=code,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=body.ttl_minutes),
        is_active=True,
    )
    db.add(ov)
    db.flush()
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="credit.override.issue",
        target_entity="credit_overrides",
        target_id=ov.id,
        after_state={"outlet_id": str(body.outlet_id), "ttl_minutes": body.ttl_minutes},
    )
    db.commit()
    return OverrideOut(override_code=code, outlet_id=body.outlet_id, expires_at=ov.expires_at)


# ---- Media ----
@router.post("/media/tokens", status_code=201)
def media_token(
    ctx: AuthDep,
    db: DbDep,
    kind: str = Query("image", pattern="^(image|signature|photo)$"),
):
    return create_upload_token(db, tenant_id=ctx.tenant_id, kind=kind, uploaded_by=ctx.user_id)


@router.post("/media/{token}/upload")
async def media_upload(
    token: str,
    ctx: AuthDep,
    db: DbDep,
    file: UploadFile = File(...),
):
    data = await file.read()
    if len(data) > 10 * 1024 * 1024:
        raise ValidationException("File too large (max 10MB)")
    write_media(db, ctx.tenant_id, token, data, file.content_type)
    db.commit()
    return {"media_token": token, "size": len(data)}


@router.get("/media/{token}/presign")
def media_presign(token: str, ctx: AuthDep, db: DbDep):
    return presign_download(db, ctx.tenant_id, token)


@router.get("/media/{token}/download")
def media_download(token: str, ctx: AuthDep, db: DbDep, exp: int, sig: str):
    from app.services.media import verify_download_sig, read_media

    if not verify_download_sig(token, exp, sig):
        raise Forbidden("Invalid or expired signature")
    data, ctype = read_media(db, ctx.tenant_id, token)
    from fastapi.responses import Response

    return Response(content=data, media_type=ctype or "application/octet-stream")


# ---- Operations overview ----
@router.get("/overview", response_model=OverviewOut)
def overview(ctx: AuthDep, db: DbDep):
    from sqlalchemy import func

    active_shifts = db.execute(
        select(func.count(DriverShift.id)).where(
            DriverShift.tenant_id == ctx.tenant_id, DriverShift.status == "ACTIVE"
        )
    ).scalar_one()

    today = datetime.now(timezone.utc).date()
    completed = db.execute(
        select(func.count(RouteStop.id)).where(
            RouteStop.tenant_id == ctx.tenant_id,
            RouteStop.status == "COMPLETED",
            func.date(RouteStop.completed_at) == today,
        )
    ).scalar_one()
    exceptions = db.execute(
        select(func.count(RouteStop.id)).where(
            RouteStop.tenant_id == ctx.tenant_id,
            RouteStop.status == "EXCEPTION",
            func.date(RouteStop.completed_at) == today,
        )
    ).scalar_one()
    cash = db.execute(
        select(func.coalesce(func.sum(Payment.amount_mad), 0)).where(
            Payment.tenant_id == ctx.tenant_id,
            func.date(Payment.collected_at) == today,
        )
    ).scalar_one()
    unresolved = db.execute(
        select(func.count(CashHandover.id)).where(
            CashHandover.tenant_id == ctx.tenant_id,
            CashHandover.status == "VARIANCE_FLAGGED",
        )
    ).scalar_one()
    critical = db.execute(
        select(func.count(SafetyIncident.id)).where(
            SafetyIncident.tenant_id == ctx.tenant_id,
            SafetyIncident.severity == "CRITICAL",
            SafetyIncident.is_resolved.is_(False),
        )
    ).scalar_one()
    # active holds: outlets in hard credit lock approximated by open EXCEPTION stops
    holds = db.execute(
        select(func.count(RouteStop.id)).where(
            RouteStop.tenant_id == ctx.tenant_id,
            RouteStop.status == "EXCEPTION",
            RouteStop.completed_at.is_(None),
        )
    ).scalar_one()

    return OverviewOut(
        active_trucks=int(active_shifts),
        completed_stops_today=int(completed),
        exceptions_today=int(exceptions),
        total_cash_collected_mad=float(cash),
        unresolved_discrepancies=int(unresolved),
        open_critical_incidents=int(critical),
        active_holds=int(holds),
    )


@router.get("/live-fleet", response_model=list[LiveFleetVehicleOut])
def get_live_fleet(ctx: AuthDep, db: DbDep):
    active_shifts = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id,
            DriverShift.status == "ACTIVE",
        )
    ).scalars().all()

    fleet: list[LiveFleetVehicleOut] = []
    for s in active_shifts:
        agent = db.get(User, s.agent_id)
        vehicle = db.get(Vehicle, s.vehicle_id)

        latest_telem = db.execute(
            select(ShiftTelemetry)
            .where(
                ShiftTelemetry.tenant_id == ctx.tenant_id,
                ShiftTelemetry.shift_id == s.id,
            )
            .order_by(ShiftTelemetry.recorded_at.desc())
        ).scalars().first()

        lat = float(latest_telem.latitude) if latest_telem else 33.5731
        lng = float(latest_telem.longitude) if latest_telem else -7.5898
        speed = float(latest_telem.speed_kmh) if (latest_telem and latest_telem.speed_kmh is not None) else 0.0
        ping_time = latest_telem.recorded_at.isoformat() if latest_telem else s.started_at.isoformat()

        fleet.append(
            LiveFleetVehicleOut(
                shift_id=s.id,
                agent_id=s.agent_id,
                agent_name=agent.full_name if agent else "Chauffeur",
                agent_phone=agent.phone if agent else "",
                vehicle_id=s.vehicle_id,
                plate_number=vehicle.plate_number if vehicle else "CAMION",
                vehicle_model=vehicle.model if vehicle else None,
                latitude=lat,
                longitude=lng,
                speed_kmh=speed,
                last_ping_at=ping_time,
                status=s.status,
            )
        )
    return fleet

