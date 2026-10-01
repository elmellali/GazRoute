from uuid import UUID

from fastapi import APIRouter, Query
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
from app.models import CylinderType, Outlet, Tenant, User, Vehicle
from app.repositories.base import get_tenant_scoped, list_tenant
from app.schemas import (
    CylinderTypeCreate,
    CylinderTypeOut,
    OutletCreate,
    OutletOut,
    OutletUpdate,
    TenantCreate,
    TenantOut,
    UserCreate,
    UserOut,
    VehicleCreate,
    VehicleOut,
)
from app.services.audit import write_audit
from fastapi import Depends

router = APIRouter(tags=["catalog"])


@router.post("/tenants", response_model=TenantOut, status_code=201)
def create_tenant(body: TenantCreate, db: DbDep) -> TenantOut:
    """Bootstrap endpoint: create a new distributor tenant (owner created separately via seed)."""
    t = Tenant(company_name=body.company_name, phone=body.phone, ice_number=body.ice_number)
    db.add(t)
    db.flush()
    db.commit()
    return TenantOut.model_validate(t)


@router.get("/me/tenant", response_model=TenantOut)
def my_tenant(ctx: AuthDep, db: DbDep) -> TenantOut:
    t = db.get(Tenant, ctx.tenant_id)
    if t is None:
        raise NotFound("Tenant not found")
    return TenantOut.model_validate(t)


@router.get("/users", response_model=list[UserOut])
def list_users(
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_DISPATCHER, ROLE_ACCOUNTANT, ROLE_AUDITOR)),
):
    return [UserOut.model_validate(u) for u in list_tenant(db, User, ctx.tenant_id)]


@router.post("/users", response_model=UserOut, status_code=201)
def create_user(
    body: UserCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER)),
):
    from app.core.security import hash_password

    if body.role not in {
        "owner",
        "dispatcher",
        "warehouse",
        "agent",
        "accountant",
        "auditor",
    }:
        raise ValidationException("invalid role")
    u = User(
        tenant_id=ctx.tenant_id,
        phone=body.phone,
        full_name=body.full_name,
        role=body.role,
        preferred_lang=body.preferred_lang,
        password_hash=hash_password(body.password) if body.password else None,
    )
    db.add(u)
    db.flush()
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="user.create",
        target_entity="users",
        target_id=u.id,
        after_state={"phone": u.phone, "role": u.role},
    )
    db.commit()
    return UserOut.model_validate(u)


@router.get("/cylinder-types", response_model=list[CylinderTypeOut])
def list_cylinders(ctx: AuthDep, db: DbDep):
    return [CylinderTypeOut.model_validate(c) for c in list_tenant(db, CylinderType, ctx.tenant_id)]


@router.post("/cylinder-types", response_model=CylinderTypeOut, status_code=201)
def create_cylinder(
    body: CylinderTypeCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_DISPATCHER, ROLE_WAREHOUSE)),
):
    if body.gas_type not in ("butane", "propane"):
        raise ValidationException("gas_type must be butane or propane")
    c = CylinderType(
        tenant_id=ctx.tenant_id,
        gas_type=body.gas_type,
        size_kg=body.size_kg,
        deposit_amount_mad=body.deposit_amount_mad,
        base_sale_price_mad=body.base_sale_price_mad,
    )
    db.add(c)
    db.flush()
    db.commit()
    return CylinderTypeOut.model_validate(c)


@router.get("/vehicles", response_model=list[VehicleOut])
def list_vehicles(ctx: AuthDep, db: DbDep):
    return [VehicleOut.model_validate(v) for v in list_tenant(db, Vehicle, ctx.tenant_id)]


@router.post("/vehicles", response_model=VehicleOut, status_code=201)
def create_vehicle(
    body: VehicleCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_DISPATCHER, ROLE_WAREHOUSE)),
):
    v = Vehicle(
        tenant_id=ctx.tenant_id,
        plate_number=body.plate_number,
        model=body.model,
        max_payload_kg=body.max_payload_kg,
    )
    db.add(v)
    db.flush()
    db.commit()
    return VehicleOut.model_validate(v)


@router.get("/outlets", response_model=list[OutletOut])
def list_outlets(ctx: AuthDep, db: DbDep):
    return [OutletOut.model_validate(o) for o in list_tenant(db, Outlet, ctx.tenant_id)]


@router.post("/outlets", response_model=OutletOut, status_code=201)
def create_outlet(
    body: OutletCreate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_DISPATCHER)),
):
    from geoalchemy2.elements import WKTElement

    if not (30 <= body.geofence_radius_m <= 200):
        raise ValidationException("geofence_radius_m must be 30-200")
    o = Outlet(
        tenant_id=ctx.tenant_id,
        name=body.name,
        contact_name=body.contact_name,
        phone=body.phone,
        location=WKTElement(f"POINT({body.longitude} {body.latitude})", srid=4326),
        geofence_radius_m=body.geofence_radius_m,
        credit_limit_mad=body.credit_limit_mad,
        payment_terms_days=body.payment_terms_days,
    )
    db.add(o)
    db.flush()
    db.commit()
    return OutletOut.model_validate(o)


@router.get("/outlets/{outlet_id}", response_model=OutletOut)
def get_outlet(outlet_id: UUID, ctx: AuthDep, db: DbDep) -> OutletOut:
    o = get_tenant_scoped(db, Outlet, ctx.tenant_id, outlet_id, "Outlet not found")
    return OutletOut.model_validate(o)


@router.patch("/outlets/{outlet_id}", response_model=OutletOut)
def update_outlet(
    outlet_id: UUID,
    body: OutletUpdate,
    ctx: AuthDep,
    db: DbDep,
    _guard=Depends(require_roles(ROLE_OWNER, ROLE_DISPATCHER)),
):
    o = get_tenant_scoped(db, Outlet, ctx.tenant_id, outlet_id, "Outlet not found")
    before = {"credit_limit_mad": float(o.credit_limit_mad), "geofence_radius_m": o.geofence_radius_m}
    data = body.model_dump(exclude_unset=True)
    lat = data.pop("latitude", None)
    lng = data.pop("longitude", None)
    for k, v in data.items():
        setattr(o, k, v)
    if lat is not None and lng is not None:
        from geoalchemy2.elements import WKTElement

        o.location = WKTElement(f"POINT({lng} {lat})", srid=4326)
    write_audit(
        db,
        tenant_id=ctx.tenant_id,
        actor_id=ctx.user_id,
        action="outlet.update",
        target_entity="outlets",
        target_id=o.id,
        before_state=before,
        after_state=body.model_dump(exclude_unset=True),
    )
    db.commit()
    return OutletOut.model_validate(o)
