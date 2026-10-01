"""Seed demo tenant, users, catalog, outlets, vehicles for pilot dry-run."""
from __future__ import annotations

import math
import sys
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal

from geoalchemy2.elements import WKTElement
from sqlalchemy import select

from app.core.database import SessionLocal, engine, Base
from app.core.security import hash_password
from app.models import (
    CylinderType,
    DriverShift,
    InventoryLocation,
    Outlet,
    Tenant,
    User,
    Vehicle,
)

# Casablanca anchors
CASABLANCA = (33.5731, -7.5898)


def _ring_point(i: int, n: int = 20, radius_deg: float = 0.04) -> tuple[float, float]:
    angle = 2 * math.pi * i / n
    lat = CASABLANCA[0] + radius_deg * math.sin(angle)
    lng = CASABLANCA[1] + radius_deg * math.cos(angle)
    return lat, lng


def seed() -> None:
    Base.metadata.create_all(engine)
    db = SessionLocal()
    try:
        existing = db.execute(
            select(Tenant).where(Tenant.company_name == "Gaz Distribution Casablanca")
        ).scalar_one_or_none()
        if existing:
            print("Seed already applied (tenant exists).")
            return

        tenant = Tenant(
            company_name="Gaz Distribution Casablanca",
            phone="+212522000001",
            ice_number="ICE00000000001",
        )
        db.add(tenant)
        db.flush()

        users_spec = [
            ("+212600000001", "Youssef Benali", "owner", "fr"),
            ("+212600000002", "Fatima Zahra", "dispatcher", "fr"),
            ("+212600000003", "Karim Idrissi", "warehouse", "fr"),
            ("+212600000004", "Ahmed Alaoui", "agent", "ar"),
            ("+212600000005", "Leila Haddad", "accountant", "fr"),
            ("+212600000006", "Audit Inspector", "auditor", "fr"),
        ]
        users: dict[str, User] = {}
        for phone, name, role, lang in users_spec:
            u = User(
                tenant_id=tenant.id,
                phone=phone,
                full_name=name,
                role=role,
                preferred_lang=lang,
                password_hash=hash_password("Passw0rd!"),
            )
            db.add(u)
            users[role] = u
        db.flush()

        cylinders = [
            CylinderType(
                tenant_id=tenant.id,
                gas_type="butane",
                size_kg=Decimal("3.00"),
                deposit_amount_mad=Decimal("30.00"),
                base_sale_price_mad=Decimal("40.00"),
            ),
            CylinderType(
                tenant_id=tenant.id,
                gas_type="butane",
                size_kg=Decimal("12.00"),
                deposit_amount_mad=Decimal("80.00"),
                base_sale_price_mad=Decimal("140.00"),
            ),
            CylinderType(
                tenant_id=tenant.id,
                gas_type="propane",
                size_kg=Decimal("35.00"),
                deposit_amount_mad=Decimal("150.00"),
                base_sale_price_mad=Decimal("450.00"),
            ),
        ]
        db.add_all(cylinders)
        db.flush()

        vehicle = Vehicle(
            tenant_id=tenant.id,
            plate_number="12345-A-6",
            model="Mercedes 814",
            max_payload_kg=Decimal("3500.00"),
        )
        vehicle2 = Vehicle(
            tenant_id=tenant.id,
            plate_number="67890-B-1",
            model="Iveco Daily",
            max_payload_kg=Decimal("2800.00"),
        )
        db.add_all([vehicle, vehicle2])
        db.flush()

        depot = InventoryLocation(
            tenant_id=tenant.id, name="Depot Casablanca Central", type="depot"
        )
        quarantine = InventoryLocation(
            tenant_id=tenant.id, name="Quarantine Zone", type="quarantine"
        )
        db.add_all([depot, quarantine])
        db.flush()

        # Initial depot stock via journal-equivalent seed movements
        from app.models import InventoryMovement
        from app.services.inventory_journal import log_movement

        # Create initial stock as adjustments FROM nothing — use a virtual source location?
        # Spec requires from/to. Seed with inventory audit adj: to=depot, from=None is allowed.
        for ct, qty in [(cylinders[0], 500), (cylinders[1], 300), (cylinders[2], 80)]:
            log_movement(
                db,
                tenant_id=tenant.id,
                cylinder_type_id=ct.id,
                cylinder_state="full",
                quantity=qty,
                from_location_id=None,
                to_location_id=depot.id,
                source_type="INVENTORY_AUDIT_ADJ",
                source_id=tenant.id,
                created_by=users["owner"].id,
            )
            # empties at depot for refill plant
            log_movement(
                db,
                tenant_id=tenant.id,
                cylinder_type_id=ct.id,
                cylinder_state="empty",
                quantity=qty // 2,
                from_location_id=None,
                to_location_id=depot.id,
                source_type="INVENTORY_AUDIT_ADJ",
                source_id=tenant.id,
                created_by=users["owner"].id,
            )

        names = [
            "Hanout Al Amal",
            "Mini-Market Nour",
            "Boulangerie Al Khadra",
            "Café Central",
            "Restaurant El Bahdja",
            "Hanout Salam",
            "Épicerie Nour Eddine",
            "Supérette Al Qods",
            "Boulangerie Riad",
            "Café des Arts",
            "Restaurant Andalous",
            "Hanout Al Fajr",
            "Mini-Market Al Wafa",
            "Boulangerie Al Amane",
            "Café Paix",
            "Restaurant Oualidia",
            "Hanout Al Munawara",
            "Épicerie Al Baraka",
            "Supérette Hassan",
            "Boulangerie Al Qawiya",
        ]
        outlet_ids = []
        for i, name in enumerate(names):
            lat, lng = _ring_point(i)
            o = Outlet(
                tenant_id=tenant.id,
                name=name,
                contact_name=f"Contact {i+1}",
                phone=f"+21266100{i:04d}",
                location=WKTElement(f"POINT({lng} {lat})", srid=4326),
                geofence_radius_m=60,
                credit_limit_mad=Decimal("2000.00"),
                payment_terms_days=7,
            )
            db.add(o)
            outlet_ids.append(o)
        db.flush()

        # Create outlet inventory locations
        for o in outlet_ids:
            db.add(
                InventoryLocation(
                    tenant_id=tenant.id,
                    name=o.name,
                    type="outlet",
                    reference_id=o.id,
                )
            )

        db.commit()
        print("SEED OK")
        print(f"tenant_id={tenant.id}")
        for phone, name, role, _ in users_spec:
            print(f"  {role:12} {phone}  Passw0rd!")
        print(f"  cylinders={len(cylinders)} vehicles=2 outlets={len(outlet_ids)} depot_stock_seeded=true")
        print("  note: create a shift+route from dashboard or API before mobile field flow")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
