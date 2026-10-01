import uuid

from pydantic import BaseModel, ConfigDict, Field
from pydantic.types import UUID4


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class OkMessage(BaseModel):
    message: str


class HealthOut(BaseModel):
    status: str
    database: bool


# ---- Auth ----
class OtpRequestIn(BaseModel):
    phone: str = Field(min_length=8, max_length=20)


class OtpRequestOut(BaseModel):
    message: str
    expires_in_seconds: int
    dev_code: str | None = None


class OtpVerifyIn(BaseModel):
    phone: str
    otp_code: str = Field(min_length=6, max_length=6)
    device_id: str | None = None


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str
    tenant_id: UUID4
    user_id: UUID4
    expires_in_seconds: int


class RefreshIn(BaseModel):
    refresh_token: str


# ---- Tenant / Users ----
class TenantCreate(BaseModel):
    company_name: str
    phone: str
    ice_number: str | None = None


class TenantOut(ORMModel):
    id: UUID4
    company_name: str
    phone: str
    ice_number: str | None
    is_active: bool


class UserCreate(BaseModel):
    phone: str
    full_name: str
    role: str
    preferred_lang: str = "fr"
    password: str | None = None


class UserOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    phone: str
    full_name: str
    role: str
    preferred_lang: str
    is_active: bool


# ---- Catalog ----
class CylinderTypeCreate(BaseModel):
    gas_type: str
    size_kg: float
    deposit_amount_mad: float = 0
    base_sale_price_mad: float


class CylinderTypeOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    gas_type: str
    size_kg: float
    deposit_amount_mad: float
    base_sale_price_mad: float
    is_active: bool


class VehicleCreate(BaseModel):
    plate_number: str
    model: str | None = None
    max_payload_kg: float | None = None


class VehicleOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    plate_number: str
    model: str | None
    max_payload_kg: float | None
    is_active: bool


class OutletCreate(BaseModel):
    name: str
    phone: str
    contact_name: str | None = None
    latitude: float
    longitude: float
    geofence_radius_m: int = 60
    credit_limit_mad: float = 0
    payment_terms_days: int = 0


class OutletUpdate(BaseModel):
    name: str | None = None
    contact_name: str | None = None
    phone: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    geofence_radius_m: int | None = None
    credit_limit_mad: float | None = None
    payment_terms_days: int | None = None
    is_active: bool | None = None


class OutletOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    name: str
    contact_name: str | None
    phone: str
    latitude: float | None = None
    longitude: float | None = None
    geofence_radius_m: int
    credit_limit_mad: float
    payment_terms_days: int
    is_active: bool


class LocationCreate(BaseModel):
    name: str
    type: str = "depot"
    reference_id: UUID4 | None = None


class LocationOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    name: str
    type: str
    reference_id: UUID4 | None


# ---- Shifts ----
class PreTripSafety(BaseModel):
    fire_extinguisher_valid: bool
    cargo_straps_secured: bool
    stacking_compliant: bool
    no_gas_leaks: bool


class ShiftStartIn(BaseModel):
    vehicle_id: UUID4
    odometer_km: float | None = None
    pre_trip_safety: PreTripSafety


class AcceptLoadLine(BaseModel):
    cylinder_type_id: UUID4
    quantity: float


class AcceptLoadIn(BaseModel):
    load_sheet_id: UUID4
    accepted_quantities: list[AcceptLoadLine]


class LoadSheetCreate(BaseModel):
    vehicle_id: UUID4
    depot_location_id: UUID4
    shift_id: UUID4 | None = None
    lines: list[AcceptLoadLine]


class LoadSheetOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    vehicle_id: UUID4
    depot_location_id: UUID4
    status: str
    shift_id: UUID4 | None


class ShiftOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    agent_id: UUID4
    vehicle_id: UUID4
    status: str
    pre_trip_safety_passed: bool
    started_at: object
    ended_at: object | None
    declared_cash_mad: float | None


class CloseoutUnloadLine(BaseModel):
    cylinder_type_id: UUID4
    state: str
    quantity: float


class CloseoutIn(BaseModel):
    unloaded_lines: list[CloseoutUnloadLine]
    declared_cash_mad: float
    cashier_user_id: UUID4
    variance_reason: str | None = None


# ---- Routes ----
class StopCreate(BaseModel):
    outlet_id: UUID4
    sequence_order: int


class RouteCreate(BaseModel):
    shift_id: UUID4
    planned_date: str
    stops: list[StopCreate]


class RouteStopOut(ORMModel):
    id: UUID4
    route_id: UUID4
    outlet_id: UUID4
    outlet_name: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    sequence_order: int
    status: str
    arrived_at: object | None
    completed_at: object | None
    arrival_method: str | None
    arrival_distance_m: float | None
    exception_reason: str | None


class RouteOut(ORMModel):
    id: UUID4
    tenant_id: UUID4
    shift_id: UUID4
    status: str
    planned_date: object
    stops: list[RouteStopOut] = []


class CheckInIn(BaseModel):
    client_event_id: UUID4
    occurred_at: str
    method: str = "geofence"
    latitude: float
    longitude: float
    accuracy_m: float


class CheckInOut(BaseModel):
    status: str
    validated: bool
    distance_meters: float | None = None
    unlocked_workflows: list[str] = []


class EnRouteIn(BaseModel):
    status: str = Field(pattern="^(EN_ROUTE|NEARBY)$")


class ExceptionIn(BaseModel):
    client_event_id: UUID4
    reason: str
    photo_media_token: str | None = None
    reschedule_date: str | None = None


# ---- Delivery ----
class DeliveryLineIn(BaseModel):
    cylinder_type_id: UUID4
    delivered_full_qty: float = 0
    returned_empty_qty: float = 0
    returned_defective_qty: float = 0
    price_override_mad: float = 0
    discount_mad: float = 0


class PaymentIn(BaseModel):
    amount_mad: float
    method: str = "cash"
    reference: str | None = None


class DeliveryIn(BaseModel):
    client_event_id: UUID4
    occurred_at: str
    recipient_name: str
    signature_media_token: str | None = None
    photo_media_token: str | None = None
    lines: list[DeliveryLineIn]
    payment: PaymentIn | None = None
    override_code: str | None = None


class DeliveryOut(BaseModel):
    delivery_note_id: UUID4
    receipt_number: str
    total_amount_mad: float
    subtotal_mad: float
    deposit_net_mad: float
    paid_amount_mad: float
    remaining_outlet_balance_mad: float
    movements_logged: int
    credit_soft_warning: bool = False


# ---- Payment standalone ----
class PaymentCreate(BaseModel):
    client_event_id: UUID4
    outlet_id: UUID4
    route_stop_id: UUID4 | None = None
    amount_mad: float
    method: str = "cash"
    reference: str | None = None
    collected_at: str | None = None


class PaymentOut(ORMModel):
    id: UUID4
    outlet_id: UUID4
    amount_mad: float
    method: str
    receipt_number: str
    handover_status: str
    collected_at: object


# ---- Safety ----
class SafetyIn(BaseModel):
    shift_id: UUID4
    incident_type: str
    severity: str
    description: str
    latitude: float | None = None
    longitude: float | None = None
    photo_media_token: str | None = None
    cylinder_type_id: UUID4 | None = None


class SafetyOut(ORMModel):
    id: UUID4
    shift_id: UUID4
    incident_type: str
    severity: str
    description: str
    photo_media_token: str | None
    is_resolved: bool
    created_at: object


# ---- Handover verify ----
class HandoverVerifyIn(BaseModel):
    verified_cash_mad: float
    variance_reason: str | None = None


class HandoverOut(ORMModel):
    id: UUID4
    shift_id: UUID4
    expected_cash_mad: float
    declared_cash_mad: float
    verified_cash_mad: float | None
    variance_mad: float | None
    status: str
    variance_reason: str | None


# ---- Credit ----
class CreditCheckIn(BaseModel):
    proposed_order_total_mad: float = 0
    override_code: str | None = None


class CreditCheckOut(BaseModel):
    current_balance_mad: float
    projected_balance_mad: float
    credit_limit_mad: float
    soft_warning: bool
    hard_lock: bool
    oldest_unpaid_days: int | None
    reason: str | None


class OverrideCreate(BaseModel):
    outlet_id: UUID4
    ttl_minutes: int = 60


class OverrideOut(BaseModel):
    override_code: str
    outlet_id: UUID4
    expires_at: object


# ---- Inventory ----
class InventoryBalanceItem(BaseModel):
    location_id: UUID4
    cylinder_type_id: UUID4
    cylinder_state: str
    quantity: float


class MovementOut(ORMModel):
    id: UUID4
    cylinder_type_id: UUID4
    cylinder_state: str
    quantity: float
    from_location_id: UUID4 | None
    to_location_id: UUID4 | None
    source_type: str
    occurred_at: object


# ---- Overview ----
class OverviewOut(BaseModel):
    active_trucks: int
    completed_stops_today: int
    exceptions_today: int
    total_cash_collected_mad: float
    unresolved_discrepancies: int
    open_critical_incidents: int
    active_holds: int


# ---- Live Fleet & Telemetry ----
class TelemetryIn(BaseModel):
    latitude: float
    longitude: float
    speed_kmh: float | None = None
    battery_level: float | None = None


class LiveFleetVehicleOut(BaseModel):
    shift_id: UUID4
    agent_id: UUID4
    agent_name: str
    agent_phone: str
    vehicle_id: UUID4
    plate_number: str
    vehicle_model: str | None = None
    latitude: float
    longitude: float
    speed_kmh: float | None = None
    last_ping_at: str
    status: str

