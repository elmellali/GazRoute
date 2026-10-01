import os
import sys
import uuid
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Ensure backend package importable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402

TEST_DB_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql+psycopg://postgres@127.0.0.1:5432/gaz_test",
)


@pytest.fixture(scope="session")
def engine():
    admin_url = TEST_DB_URL.rsplit("/", 1)[0] + "/postgres"
    admin = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    db_name = TEST_DB_URL.rsplit("/", 1)[1]
    with admin.connect() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": db_name}
        ).scalar()
        if not exists:
            conn.execute(text(f'CREATE DATABASE "{db_name}"'))
    admin.dispose()

    eng = create_engine(TEST_DB_URL, future=True)
    # Ensure PostGIS
    with eng.connect() as conn:
        conn.execute(text('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'))
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
        conn.commit()
    Base.metadata.drop_all(eng)
    Base.metadata.create_all(eng)
    yield eng
    Base.metadata.drop_all(eng)
    eng.dispose()


@pytest.fixture()
def db_session(engine):
    TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = TestingSession()
    yield session
    session.rollback()
    session.close()


@pytest.fixture()
def client(engine):
    TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def _override_get_db():
        session = TestingSession()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = _override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture()
def tenant_ctx(client, engine):
    """Create tenant + owner + agent users; return tokens and ids."""
    TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    from app.core.security import hash_password
    from app.models import CylinderType, InventoryLocation, Outlet, Tenant, User, Vehicle
    from geoalchemy2.elements import WKTElement
    from decimal import Decimal

    session = TestingSession()
    suffix = uuid.uuid4().hex[:8]
    tenant = Tenant(
        company_name=f"Tenant {suffix}",
        phone=f"+212522{suffix[:7]}",
    )
    session.add(tenant)
    session.flush()

    owner = User(
        tenant_id=tenant.id,
        phone=f"+212611{suffix[:6]}1",
        full_name="Owner",
        role="owner",
        password_hash=hash_password("x"),
    )
    agent = User(
        tenant_id=tenant.id,
        phone=f"+212611{suffix[:6]}2",
        full_name="Agent",
        role="agent",
        password_hash=hash_password("x"),
    )
    warehouse = User(
        tenant_id=tenant.id,
        phone=f"+212611{suffix[:6]}3",
        full_name="Warehouse",
        role="warehouse",
        password_hash=hash_password("x"),
    )
    dispatcher = User(
        tenant_id=tenant.id,
        phone=f"+212611{suffix[:6]}4",
        full_name="Dispatcher",
        role="dispatcher",
        password_hash=hash_password("x"),
    )
    accountant = User(
        tenant_id=tenant.id,
        phone=f"+212611{suffix[:6]}5",
        full_name="Accountant",
        role="accountant",
        password_hash=hash_password("x"),
    )
    # second tenant for isolation tests
    tenant2 = Tenant(company_name=f"T2 {suffix}", phone=f"+212522{suffix[:6]}9")
    session.add(tenant2)
    session.flush()
    other_user = User(
        tenant_id=tenant2.id,
        phone=f"+212611{suffix[:6]}9",
        full_name="Other",
        role="owner",
        password_hash=hash_password("x"),
    )
    session.add_all([owner, agent, warehouse, dispatcher, accountant, other_user])

    ct = CylinderType(
        tenant_id=tenant.id,
        gas_type="butane",
        size_kg=Decimal("12.00"),
        deposit_amount_mad=Decimal("80"),
        base_sale_price_mad=Decimal("140"),
    )
    session.add(ct)
    vehicle = Vehicle(tenant_id=tenant.id, plate_number=f"PL-{suffix}", model="Test")
    session.add(vehicle)
    depot = InventoryLocation(tenant_id=tenant.id, name="Depot", type="depot")
    session.add(dump := depot)
    session.flush()

    outlet = Outlet(
        tenant_id=tenant.id,
        name="Test Outlet",
        phone="+212660000000",
        location=WKTElement("POINT(-7.5898 33.5731)", srid=4326),
        geofence_radius_m=60,
        credit_limit_mad=Decimal("5000"),
    )
    session.add(outlet)
    # outlet location
    session.flush()
    ol = InventoryLocation(
        tenant_id=tenant.id, name="Test Outlet", type="outlet", reference_id=outlet.id
    )
    session.add(ol)
    session.commit()

    data = {
        "tenant_id": tenant.id,
        "tenant2_id": tenant2.id,
        "owner_id": owner.id,
        "agent_id": agent.id,
        "warehouse_id": warehouse.id,
        "dispatcher_id": dispatcher.id,
        "accountant_id": accountant.id,
        "other_user_id": other_user.id,
        "cylinder_type_id": ct.id,
        "vehicle_id": vehicle.id,
        "depot_id": depot.id,
        "outlet_id": outlet.id,
        "outlet_location_id": ol.id,
        "phones": {
            "owner": owner.phone,
            "agent": agent.phone,
            "warehouse": warehouse.phone,
            "dispatcher": dispatcher.phone,
            "accountant": accountant.phone,
            "other": other_user.phone,
        },
    }
    session.close()
    return data


def login(client, phone: str, device_id: str = "test-device") -> dict:
    r = client.post("/api/v1/auth/otp/request", json={"phone": phone})
    assert r.status_code == 200, r.text
    code = r.json().get("dev_code")
    assert code, "dev_code required in test ENV"
    r = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "otp_code": code, "device_id": device_id},
    )
    assert r.status_code == 200, r.text
    return r.json()


@pytest.fixture()
def tokens(client, tenant_ctx):
    return {
        "owner": login(client, tenant_ctx["phones"]["owner"]),
        "agent": login(client, tenant_ctx["phones"]["agent"]),
        "warehouse": login(client, tenant_ctx["phones"]["warehouse"]),
        "dispatcher": login(client, tenant_ctx["phones"]["dispatcher"]),
        "accountant": login(client, tenant_ctx["phones"]["accountant"]),
        "other": login(client, tenant_ctx["phones"]["other"]),
    }


def auth(tok: dict) -> dict:
    return {"Authorization": f"Bearer {tok['access_token']}"}
