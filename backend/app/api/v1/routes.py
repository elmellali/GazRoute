from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select

from app.core.config import settings
from app.core.deps import ROLE_AGENT, ROLE_DISPATCHER, ROLE_OWNER, AuthDep, DbDep, require_roles
from app.core.exceptions import Conflict, Forbidden, NotFound, ValidationException
from app.models import DeliveryNote, Outlet, Payment, Route, RouteStop, DriverShift
from app.schemas import CheckInIn, CheckInOut, ExceptionIn, RouteCreate, RouteOut, RouteStopOut, StopCreate
from app.services.audit import write_audit
from app.services.geofence import validate_arrival

router = APIRouter(prefix="/routes", tags=["routes"])

ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "PENDING": {"EN_ROUTE", "EXCEPTION"},
    "EN_ROUTE": {"NEARBY", "ARRIVED", "EXCEPTION"},
    "NEARBY": {"ARRIVED", "EXCEPTION"},
    "ARRIVED": {"IN_SERVICE", "COMPLETED", "EXCEPTION"},
    "IN_SERVICE": {"COMPLETED", "EXCEPTION"},
    "COMPLETED": set(),
    "EXCEPTION": set(),
}


def _get_stop(db, tenant_id: UUID, stop_id: UUID) -> RouteStop:
    stop = db.execute(
        select(RouteStop).where(RouteStop.tenant_id == tenant_id, RouteStop.id == stop_id)
    ).scalar_one_or_none()
    if stop is None:
        raise NotFound("Route stop not found")
    return stop


def _get_route(db, tenant_id: UUID, route_id: UUID) -> Route:
    route = db.execute(
        select(Route).where(Route.tenant_id == tenant_id, Route.id == route_id)
    ).scalar_one_or_none()
    if route is None:
        raise NotFound("Route not found")
    return route


def _assert_agent_owns_stop(ctx, db, stop: RouteStop) -> None:
    if ctx.role != ROLE_AGENT:
        return
    route = _get_route(db, ctx.tenant_id, stop.route_id)
    shift = db.get(DriverShift, route.shift_id)
    if shift is None or shift.agent_id != ctx.user_id:
        raise Forbidden("Stop not assigned to this agent")


@router.post("", response_model=RouteOut, status_code=201)
def create_route(
    body: RouteCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_DISPATCHER, ROLE_OWNER)),
):
    shift = db.execute(
        select(DriverShift).where(
            DriverShift.tenant_id == ctx.tenant_id, DriverShift.id == body.shift_id
        )
    ).scalar_one_or_none()
    if shift is None:
        raise NotFound("Shift not found")
    if not body.stops:
        raise ValidationException("Route requires at least one stop")

    try:
        planned = datetime.fromisoformat(body.planned_date.replace("Z", "+00:00"))
    except ValueError:
        raise ValidationException("planned_date must be ISO8601")

    route = Route(
        tenant_id=ctx.tenant_id,
        shift_id=body.shift_id,
        planned_date=planned,
        status="DRAFT",
        dispatcher_id=ctx.user_id,
    )
    db.add(route)
    db.flush()

    seen_seq: set[int] = set()
    for s in body.stops:
        if s.sequence_order in seen_seq:
            raise ValidationException("duplicate sequence_order")
        seen_seq.add(s.sequence_order)
        outlet = db.execute(
            select(Outlet).where(Outlet.tenant_id == ctx.tenant_id, Outlet.id == s.outlet_id)
        ).scalar_one_or_none()
        if outlet is None:
            raise NotFound(f"Outlet {s.outlet_id} not found")
        db.add(
            RouteStop(
                tenant_id=ctx.tenant_id,
                route_id=route.id,
                outlet_id=s.outlet_id,
                sequence_order=s.sequence_order,
                status="PENDING",
                assigned_agent_id=shift.agent_id,
            )
        )
    db.flush()
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="route.create",
        target_entity="routes",
        target_id=route.id,
        after_state={"stops": len(body.stops)},
    )
    db.commit()
    return _route_out(db, route)


@router.get("", response_model=list[RouteOut])
def list_routes(ctx: AuthDep, db: DbDep, limit: int = 50):
    routes = db.execute(
        select(Route).where(Route.tenant_id == ctx.tenant_id).order_by(Route.created_at.desc()).limit(limit)
    ).scalars().all()
    return [_route_out(db, r) for r in routes]


@router.get("/mine", response_model=list[RouteOut])
def my_routes(ctx: AuthDep, db: DbDep):
    if ctx.role != ROLE_AGENT:
        raise Forbidden("Agents only")
    rows = db.execute(
        select(Route)
        .join(DriverShift, Route.shift_id == DriverShift.id)
        .where(Route.tenant_id == ctx.tenant_id, DriverShift.agent_id == ctx.user_id)
        .order_by(Route.planned_date.desc())
    ).scalars().all()
    return [_route_out(db, r) for r in rows]


@router.get("/{route_id}", response_model=RouteOut)
def get_route(route_id: UUID, ctx: AuthDep, db: DbDep) -> RouteOut:
    route = _get_route(db, ctx.tenant_id, route_id)
    return _route_out(db, route)


@router.post("/{route_id}/publish", response_model=RouteOut)
def publish_route(
    route_id: UUID,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_DISPATCHER, ROLE_OWNER)),
):
    route = _get_route(db, ctx.tenant_id, route_id)
    if route.status != "DRAFT":
        raise Conflict("Only DRAFT routes can be published")
    route.status = "PUBLISHED"
    db.commit()
    return _route_out(db, route)


@router.post("/{route_id}/optimize", response_model=RouteOut)
def optimize_route(
    route_id: UUID,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_DISPATCHER, ROLE_OWNER)),
):
    import math

    route = _get_route(db, ctx.tenant_id, route_id)
    if route.status != "DRAFT":
        raise Conflict("Only DRAFT routes can be optimized")

    stops = db.execute(
        select(RouteStop)
        .where(RouteStop.route_id == route.id)
        .order_by(RouteStop.sequence_order)
    ).scalars().all()

    if len(stops) <= 1:
        return _route_out(db, route)

    def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        r = 6371.0
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (
            math.sin(dlat / 2) ** 2
            + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
        )
        return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    depot_anchor = (33.5731, -7.5898)
    unvisited = list(stops)
    curr_pos = depot_anchor
    ordered = []

    while unvisited:
        best_stop = min(
            unvisited,
            key=lambda s: _haversine(
                curr_pos[0],
                curr_pos[1],
                s.latitude if s.latitude is not None else depot_anchor[0],
                s.longitude if s.longitude is not None else depot_anchor[1],
            ),
        )
        ordered.append(best_stop)
        unvisited.remove(best_stop)
        curr_pos = (
            best_stop.latitude if best_stop.latitude is not None else depot_anchor[0],
            best_stop.longitude if best_stop.longitude is not None else depot_anchor[1],
        )

    # 1. Temporarily assign negative sequence to avoid unique constraint collision
    for idx, s in enumerate(ordered):
        s.sequence_order = -(idx + 1)
    db.flush()

    # 2. Assign final optimized sequence numbers
    for idx, s in enumerate(ordered):
        s.sequence_order = idx + 1

    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="route.optimize_tsp",
        target_entity="routes",
        target_id=route.id,
        after_state={"stops_count": len(ordered)},
    )
    db.commit()
    return _route_out(db, route)


@router.post("/{route_id}/stops", response_model=RouteOut)
def add_stop_to_route(
    route_id: UUID,
    body: StopCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_DISPATCHER, ROLE_OWNER)),
):
    route = _get_route(db, ctx.tenant_id, route_id)
    if route.status != "DRAFT":
        raise Conflict("Stops can only be added to DRAFT routes")

    shift = db.get(DriverShift, route.shift_id)
    outlet = db.execute(
        select(Outlet).where(Outlet.tenant_id == ctx.tenant_id, Outlet.id == body.outlet_id)
    ).scalar_one_or_none()
    if outlet is None:
        raise NotFound("Outlet not found")

    existing_stops = db.execute(
        select(RouteStop).where(RouteStop.route_id == route.id)
    ).scalars().all()
    max_seq = max([s.sequence_order for s in existing_stops], default=0)

    stop = RouteStop(
        tenant_id=ctx.tenant_id,
        route_id=route.id,
        outlet_id=body.outlet_id,
        sequence_order=max_seq + 1,
        status="PENDING",
        assigned_agent_id=shift.agent_id if shift else None,
    )
    db.add(stop)
    db.commit()
    return _route_out(db, route)




@router.get("/stops/{stop_id}", response_model=RouteStopOut)
def get_stop(stop_id: UUID, ctx: AuthDep, db: DbDep) -> RouteStopOut:
    stop = _get_stop(db, ctx.tenant_id, stop_id)
    return RouteStopOut.model_validate(stop)


@router.post("/stops/{stop_id}/en-route", response_model=RouteStopOut)
def set_en_route(
    stop_id: UUID,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT)),
):
    stop = _get_stop(db, ctx.tenant_id, stop_id)
    _assert_agent_owns_stop(ctx, db, stop)
    if "EN_ROUTE" not in ALLOWED_TRANSITIONS.get(stop.status, set()):
        raise Conflict(f"Cannot transition from {stop.status} to EN_ROUTE")
    stop.status = "EN_ROUTE"
    route = _get_route(db, ctx.tenant_id, stop.route_id)
    if route.status == "PUBLISHED":
        route.status = "IN_PROGRESS"
    db.commit()
    return RouteStopOut.model_validate(stop)


@router.post("/stops/{stop_id}/check-in", response_model=CheckInOut)
def check_in(
    stop_id: UUID,
    body: CheckInIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT)),
):
    stop = _get_stop(db, ctx.tenant_id, stop_id)
    _assert_agent_owns_stop(ctx, db, stop)
    if stop.status in ("COMPLETED", "EXCEPTION"):
        raise Conflict("Stop already finalized")

    result = validate_arrival(
        db,
        tenant_id=ctx.tenant_id,
        outlet_id=stop.outlet_id,
        latitude=body.latitude,
        longitude=body.longitude,
        accuracy_m=body.accuracy_m,
        accuracy_limit_m=settings.gps_accuracy_limit_m,
    )

    method = body.method
    if method == "geofence":
        if not result.inside_radius:
            raise ValidationException(
                f"Outside geofence ({result.distance_meters} m > radius)"
            )
        if not result.accuracy_ok:
            raise ValidationException(
                f"GPS accuracy {body.accuracy_m} m exceeds limit {settings.gps_accuracy_limit_m} m"
            )
    elif method == "manual_proximity":
        # still require within radius for manual confirm
        if not result.inside_radius:
            raise ValidationException("Manual check-in still requires proximity within radius")
    elif method == "supervisor_override":
        if ctx.role == ROLE_AGENT:
            # agents cannot self-override without dispatcher — treat as validation
            if not result.inside_radius:
                raise ValidationException("Supervisor override not authorized for agent")
    else:
        raise ValidationException("invalid method")

    try:
        occurred = datetime.fromisoformat(body.occurred_at.replace("Z", "+00:00"))
    except ValueError:
        raise ValidationException("occurred_at must be ISO8601")

    stop.status = "ARRIVED"
    stop.arrived_at = occurred
    stop.arrival_method = method
    stop.arrival_distance_m = result.distance_meters

    route = _get_route(db, ctx.tenant_id, stop.route_id)
    if route.status == "PUBLISHED":
        route.status = "IN_PROGRESS"

    db.commit()
    return CheckInOut(
        status="arrived",
        validated=True,
        distance_meters=result.distance_meters,
        unlocked_workflows=["delivery", "return", "payment", "exception"],
    )


@router.post("/stops/{stop_id}/exception", response_model=RouteStopOut)
def log_exception(
    stop_id: UUID,
    body: ExceptionIn,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT, ROLE_DISPATCHER)),
):
    stop = _get_stop(db, ctx.tenant_id, stop_id)
    if ctx.role == ROLE_AGENT:
        _assert_agent_owns_stop(ctx, db, stop)
    if stop.status in ("COMPLETED", "EXCEPTION"):
        raise Conflict("Stop already finalized")
    stop.status = "EXCEPTION"
    stop.exception_reason = body.reason
    stop.completed_at = datetime.now(timezone.utc)
    db.commit()
    return RouteStopOut.model_validate(stop)


@router.post("/stops/{stop_id}/mark-in-service", response_model=RouteStopOut)
def mark_in_service(
    stop_id: UUID,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_AGENT)),
):
    stop = _get_stop(db, ctx.tenant_id, stop_id)
    _assert_agent_owns_stop(ctx, db, stop)
    if stop.status == "ARRIVED":
        stop.status = "IN_SERVICE"
        db.commit()
    elif stop.status == "IN_SERVICE":
        pass
    else:
        raise Conflict(f"Cannot enter IN_SERVICE from {stop.status}")
    return RouteStopOut.model_validate(stop)


def _route_out(db, route: Route) -> RouteOut:
    stops = db.execute(
        select(RouteStop)
        .where(RouteStop.route_id == route.id)
        .order_by(RouteStop.sequence_order)
    ).scalars().all()
    return RouteOut(
        id=route.id,
        tenant_id=route.tenant_id,
        shift_id=route.shift_id,
        status=route.status,
        planned_date=route.planned_date,
        stops=[RouteStopOut.model_validate(s) for s in stops],
    )
