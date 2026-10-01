import struct
import uuid
from datetime import datetime

from geoalchemy2 import Geography
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.base import TimestampMixin


def _extract_lat_lng(location) -> tuple[float | None, float | None]:
    if location is None:
        return None, None
    if hasattr(location, "data") and location.data is not None:
        if isinstance(location.data, (bytes, memoryview)):
            try:
                b = bytes(location.data)
                lng, lat = struct.unpack("<dd", b[-16:])
                return round(lat, 6), round(lng, 6)
            except Exception:
                pass
        elif isinstance(location.data, str) and "POINT(" in location.data.upper():
            try:
                parts = location.data.upper().split("POINT(")[1].split(")")[0].strip().split()
                return round(float(parts[1]), 6), round(float(parts[0]), 6)
            except Exception:
                pass
    s = str(location)
    if "POINT(" in s.upper():
        try:
            parts = s.upper().split("POINT(")[1].split(")")[0].strip().split()
            return round(float(parts[1]), 6), round(float(parts[0]), 6)
        except Exception:
            pass
    return None, None



class Tenant(Base, TimestampMixin):
    __tablename__ = "tenants"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_name: Mapped[str] = mapped_column(String(150), nullable=False)
    ice_number: Mapped[str | None] = mapped_column(String(15), unique=True)
    phone: Mapped[str] = mapped_column(String(20), nullable=False)
    settings_json: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict, server_default="{}")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class User(Base, TimestampMixin):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("tenant_id", "phone", name="uq_users_tenant_phone"),
        CheckConstraint(
            "role IN ('owner','dispatcher','warehouse','agent','accountant','auditor')",
            name="ck_users_role",
        ),
        CheckConstraint("preferred_lang IN ('fr','ar')", name="ck_users_lang"),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    phone: Mapped[str] = mapped_column(String(20), nullable=False)
    full_name: Mapped[str] = mapped_column(String(100), nullable=False)
    role: Mapped[str] = mapped_column(String(30), nullable=False)
    preferred_lang: Mapped[str] = mapped_column(String(5), nullable=False, default="fr")
    password_hash: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class OtpCode(Base, TimestampMixin):
    __tablename__ = "otp_codes"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)


class IdempotencyRecord(Base, TimestampMixin):
    __tablename__ = "idempotency_records"
    __table_args__ = (UniqueConstraint("tenant_id", "idempotency_key", name="uq_idem_tenant_key"),)

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False
    )
    idempotency_key: Mapped[str] = mapped_column(String(100), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    response_status: Mapped[int] = mapped_column(Integer, nullable=False)
    response_body: Mapped[dict] = mapped_column(JSONB, nullable=False)


class Outlet(Base, TimestampMixin):
    __tablename__ = "outlets"
    __table_args__ = (CheckConstraint("geofence_radius_m BETWEEN 30 AND 200", name="ck_outlets_radius"),)

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    contact_name: Mapped[str | None] = mapped_column(String(100))
    phone: Mapped[str] = mapped_column(String(20), nullable=False)
    location = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=False
    )
    geofence_radius_m: Mapped[int] = mapped_column(Integer, nullable=False, default=60)
    credit_limit_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    payment_terms_days: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    @property
    def latitude(self) -> float | None:
        return _extract_lat_lng(self.location)[0]

    @property
    def longitude(self) -> float | None:
        return _extract_lat_lng(self.location)[1]



class CylinderType(Base, TimestampMixin):
    __tablename__ = "cylinder_types"
    __table_args__ = (
        UniqueConstraint("tenant_id", "gas_type", "size_kg", name="uq_cylinder_tenant_gas_size"),
        CheckConstraint("gas_type IN ('butane','propane')", name="ck_cylinder_gas_type"),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    gas_type: Mapped[str] = mapped_column(String(20), nullable=False)
    size_kg: Mapped[float] = mapped_column(Numeric(6, 2), nullable=False)
    deposit_amount_mad: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False, default=0)
    base_sale_price_mad: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Vehicle(Base, TimestampMixin):
    __tablename__ = "vehicles"
    __table_args__ = (UniqueConstraint("tenant_id", "plate_number", name="uq_vehicles_tenant_plate"),)

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    plate_number: Mapped[str] = mapped_column(String(30), nullable=False)
    model: Mapped[str | None] = mapped_column(String(50))
    max_payload_kg: Mapped[float | None] = mapped_column(Numeric(8, 2))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class InventoryLocation(Base, TimestampMixin):
    __tablename__ = "inventory_locations"
    __table_args__ = (CheckConstraint("type IN ('depot','vehicle','outlet','quarantine')", name="ck_location_type"),)

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type: Mapped[str] = mapped_column(String(30), nullable=False)
    reference_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True))


class DriverShift(Base, TimestampMixin):
    __tablename__ = "driver_shifts"
    __table_args__ = (
        CheckConstraint(
            "status IN ('ACTIVE','RECONCILED','VARIANCE_FLAGGED','CLOSED')",
            name="ck_shift_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    agent_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    vehicle_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("vehicles.id"), nullable=False)
    depot_location_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("inventory_locations.id")
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="ACTIVE")
    pre_trip_safety_passed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    pre_trip_payload: Mapped[dict | None] = mapped_column(JSONB)
    odometer_km: Mapped[float | None] = mapped_column(Numeric(12, 2))
    declared_cash_mad: Mapped[float | None] = mapped_column(Numeric(12, 2))
    notes: Mapped[str | None] = mapped_column(Text)


class InventoryMovement(Base, TimestampMixin):
    __tablename__ = "inventory_movements"
    __table_args__ = (
        UniqueConstraint("tenant_id", "client_event_id", name="uq_inv_mvmt_tenant_client_event"),
        CheckConstraint("quantity > 0", name="ck_inv_qty_positive"),
        CheckConstraint("cylinder_state IN ('full','empty','defective')", name="ck_inv_state"),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    cylinder_type_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("cylinder_types.id"), nullable=False
    )
    cylinder_state: Mapped[str] = mapped_column(String(30), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    from_location_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("inventory_locations.id")
    )
    to_location_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("inventory_locations.id")
    )
    source_type: Mapped[str] = mapped_column(String(50), nullable=False)
    source_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), nullable=False)
    created_by: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    client_event_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True))


class Route(Base, TimestampMixin):
    __tablename__ = "routes"
    __table_args__ = (
        CheckConstraint(
            "status IN ('DRAFT','PUBLISHED','IN_PROGRESS','COMPLETED')",
            name="ck_route_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    shift_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("driver_shifts.id"), nullable=False, index=True
    )
    planned_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="DRAFT")
    dispatcher_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))


class RouteStop(Base, TimestampMixin):
    __tablename__ = "route_stops"
    __table_args__ = (
        UniqueConstraint("route_id", "sequence_order", name="uq_route_stop_seq"),
        CheckConstraint(
            "status IN ('PENDING','EN_ROUTE','NEARBY','ARRIVED','IN_SERVICE','COMPLETED','EXCEPTION')",
            name="ck_stop_status",
        ),
        CheckConstraint(
            "arrival_method IS NULL OR arrival_method IN ('geofence','manual_proximity','supervisor_override')",
            name="ck_arrival_method",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    route_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("routes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    outlet_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("outlets.id"), nullable=False, index=True
    )
    sequence_order: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="PENDING")
    arrived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    arrival_method: Mapped[str | None] = mapped_column(String(20))
    arrival_distance_m: Mapped[float | None] = mapped_column(Numeric(8, 2))
    exception_reason: Mapped[str | None] = mapped_column(String(50))
    assigned_agent_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))

    outlet: Mapped["Outlet"] = relationship("Outlet", lazy="joined")

    @property
    def outlet_name(self) -> str | None:
        return self.outlet.name if self.outlet else None

    @property
    def latitude(self) -> float | None:
        return self.outlet.latitude if self.outlet else None

    @property
    def longitude(self) -> float | None:
        return self.outlet.longitude if self.outlet else None



class LoadSheet(Base, TimestampMixin):
    __tablename__ = "load_sheets"
    __table_args__ = (
        CheckConstraint("status IN ('PENDING_ACCEPT','ACCEPTED','VOID')", name="ck_load_status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    shift_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("driver_shifts.id"))
    vehicle_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("vehicles.id"), nullable=False)
    depot_location_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("inventory_locations.id"), nullable=False
    )
    warehouse_user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="PENDING_ACCEPT")
    client_event_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), unique=True)


class LoadSheetLine(Base):
    __tablename__ = "load_sheet_lines"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    load_sheet_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("load_sheets.id", ondelete="CASCADE"), nullable=False
    )
    cylinder_type_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("cylinder_types.id"), nullable=False
    )
    quantity: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)


class DeliveryNote(Base, TimestampMixin):
    __tablename__ = "delivery_notes"
    __table_args__ = (
        UniqueConstraint("tenant_id", "receipt_number", name="uq_dn_tenant_receipt"),
        UniqueConstraint("tenant_id", "client_event_id", name="uq_dn_tenant_client_event"),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    route_stop_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("route_stops.id"), nullable=False, index=True
    )
    outlet_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("outlets.id"), nullable=False, index=True
    )
    shift_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("driver_shifts.id"))
    agent_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    receipt_number: Mapped[str] = mapped_column(String(50), nullable=False)
    recipient_name: Mapped[str] = mapped_column(String(100), nullable=False)
    signature_media_token: Mapped[str | None] = mapped_column(String(255))
    photo_media_token: Mapped[str | None] = mapped_column(String(255))
    subtotal_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    deposit_net_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    total_amount_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    client_event_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), nullable=False)


class DeliveryNoteLine(Base):
    __tablename__ = "delivery_note_lines"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    delivery_note_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("delivery_notes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    cylinder_type_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("cylinder_types.id"), nullable=False
    )
    delivered_full_qty: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False, default=0)
    returned_empty_qty: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False, default=0)
    returned_defective_qty: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False, default=0)
    applied_unit_price_mad: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    applied_deposit_rate_mad: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    line_total_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)


class Payment(Base, TimestampMixin):
    __tablename__ = "payments"
    __table_args__ = (
        UniqueConstraint("tenant_id", "client_event_id", name="uq_pay_tenant_client_event"),
        UniqueConstraint("tenant_id", "receipt_number", name="uq_pay_tenant_receipt"),
        CheckConstraint("amount_mad > 0", name="ck_pay_amount_positive"),
        CheckConstraint(
            "method IN ('cash','check','bank_transfer','mobile_wallet')",
            name="ck_pay_method",
        ),
        CheckConstraint(
            "handover_status IN ('COLLECTED','DECLARED','HANDED_OVER','VERIFIED')",
            name="ck_pay_handover",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    outlet_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("outlets.id"), nullable=False, index=True
    )
    route_stop_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("route_stops.id"))
    agent_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    amount_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    method: Mapped[str] = mapped_column(String(30), nullable=False)
    reference: Mapped[str | None] = mapped_column(String(100))
    receipt_number: Mapped[str] = mapped_column(String(50), nullable=False)
    collected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    shift_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("driver_shifts.id"))
    client_event_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), nullable=False)
    handover_status: Mapped[str] = mapped_column(String(30), nullable=False, default="COLLECTED")


class CashHandover(Base, TimestampMixin):
    __tablename__ = "cash_handovers"
    __table_args__ = (
        CheckConstraint(
            "status IN ('DECLARED','HANDED_OVER','VERIFIED','VARIANCE_FLAGGED')",
            name="ck_handover_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    shift_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("driver_shifts.id"), nullable=False, index=True
    )
    agent_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    cashier_user_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    expected_cash_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    declared_cash_mad: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    verified_cash_mad: Mapped[float | None] = mapped_column(Numeric(12, 2))
    variance_mad: Mapped[float | None] = mapped_column(Numeric(12, 2))
    variance_reason: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="DECLARED")


class SafetyIncident(Base, TimestampMixin):
    __tablename__ = "safety_incidents"
    __table_args__ = (CheckConstraint("severity IN ('LOW','HIGH','CRITICAL')", name="ck_incident_severity"),)

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    shift_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("driver_shifts.id"), nullable=False, index=True
    )
    reported_by: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    incident_type: Mapped[str] = mapped_column(String(50), nullable=False)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    location = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=True
    )
    photo_media_token: Mapped[str | None] = mapped_column(String(255))
    cylinder_type_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("cylinder_types.id")
    )
    is_resolved: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))


class AuditLog(Base, TimestampMixin):
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    action: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    target_entity: Mapped[str] = mapped_column(String(50), nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), nullable=False)
    before_state: Mapped[dict | None] = mapped_column(JSONB)
    after_state: Mapped[dict | None] = mapped_column(JSONB)
    ip_address: Mapped[str | None] = mapped_column(String(45))


class CreditOverride(Base, TimestampMixin):
    __tablename__ = "credit_overrides"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    outlet_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("outlets.id"), nullable=False, index=True
    )
    issued_by: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    override_code: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class MediaObject(Base, TimestampMixin):
    __tablename__ = "media_objects"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    media_token: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    kind: Mapped[str] = mapped_column(String(30), nullable=False, default="image")
    storage_path: Mapped[str] = mapped_column(String(500), nullable=False)
    content_type: Mapped[str | None] = mapped_column(String(100))
    uploaded_by: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))


class ShiftTelemetry(Base, TimestampMixin):
    __tablename__ = "shift_telemetry"

    id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    shift_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("driver_shifts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    agent_id: Mapped[uuid.UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    latitude: Mapped[float] = mapped_column(Numeric(10, 6), nullable=False)
    longitude: Mapped[float] = mapped_column(Numeric(10, 6), nullable=False)
    speed_kmh: Mapped[float | None] = mapped_column(Numeric(6, 2))
    battery_level: Mapped[float | None] = mapped_column(Numeric(5, 2))
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

