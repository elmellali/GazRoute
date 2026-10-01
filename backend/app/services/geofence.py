"""PostGIS geofence distance validation."""
from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.orm import Session


@dataclass
class GeofenceResult:
    outlet_id: UUID
    distance_meters: float
    inside_radius: bool
    accuracy_ok: bool


def validate_arrival(
    db: Session,
    *,
    tenant_id: UUID,
    outlet_id: UUID,
    latitude: float,
    longitude: float,
    accuracy_m: float,
    accuracy_limit_m: float = 50.0,
) -> GeofenceResult:
    row = db.execute(
        text(
            """
            SELECT
                o.id AS outlet_id,
                o.geofence_radius_m,
                ST_Distance(
                    o.location,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
                ) AS distance_meters,
                ST_DWithin(
                    o.location,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                    o.geofence_radius_m
                ) AS inside_radius
            FROM outlets o
            WHERE o.id = :outlet_id AND o.tenant_id = :tenant_id
            """
        ),
        {"lng": longitude, "lat": latitude, "outlet_id": outlet_id, "tenant_id": tenant_id},
    ).mappings().first()
    if row is None:
        raise ValueError("Outlet not found")
    dist = float(row["distance_meters"])
    return GeofenceResult(
        outlet_id=row["outlet_id"],
        distance_meters=round(dist, 2),
        inside_radius=bool(row["inside_radius"]),
        accuracy_ok=accuracy_m <= accuracy_limit_m,
    )
