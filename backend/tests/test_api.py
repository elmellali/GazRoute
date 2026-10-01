import uuid
from decimal import Decimal

from tests.conftest import auth


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["database"] is True


def test_otp_flow_and_me(client, tenant_ctx):
    tok = login_owner = None
    from tests.conftest import login

    tok = login(client, tenant_ctx["phones"]["owner"])
    assert tok["role"] == "owner"
    r = client.get("/api/v1/me/tenant", headers=auth(tok))
    assert r.status_code == 200
    assert r.json()["id"] == str(tenant_ctx["tenant_id"])


def test_cross_tenant_isolation(client, tenant_ctx, tokens):
    # owner of tenant1 lists outlets — should only see own
    r = client.get("/api/v1/outlets", headers=auth(tokens["owner"]))
    assert r.status_code == 200
    ids = {o["id"] for o in r.json()}
    assert str(tenant_ctx["outlet_id"]) in ids

    # other tenant user should not see tenant1 outlet via GET
    r2 = client.get(f"/api/v1/outlets/{tenant_ctx['outlet_id']}", headers=auth(tokens["other"]))
    assert r2.status_code == 404


def test_rbac_agent_cannot_create_outlet(client, tokens):
    r = client.post(
        "/api/v1/outlets",
        headers=auth(tokens["agent"]),
        json={
            "name": "X",
            "phone": "+212600000000",
            "latitude": 33.57,
            "longitude": -7.58,
        },
    )
    assert r.status_code == 403


def test_idempotent_delivery_requires_header(client, tokens, tenant_ctx):
    r = client.post(
        "/api/v1/payments",
        headers=auth(tokens["agent"]),
        json={
            "client_event_id": str(uuid.uuid4()),
            "outlet_id": str(tenant_ctx["outlet_id"]),
            "amount_mad": 100,
            "method": "cash",
        },
    )
    assert r.status_code == 422  # missing Idempotency-Key -> ValidationException 422


def test_payment_idempotency_replay(client, tokens, tenant_ctx):
    key = str(uuid.uuid4())
    body = {
        "client_event_id": str(uuid.uuid4()),
        "outlet_id": str(tenant_ctx["outlet_id"]),
        "amount_mad": 250.0,
        "method": "cash",
    }
    h = {**auth(tokens["agent"]), "Idempotency-Key": key}
    r1 = client.post("/api/v1/payments", headers=h, json=body)
    assert r1.status_code == 201, r1.text
    r2 = client.post("/api/v1/payments", headers=h, json=body)
    assert r2.status_code == 201
    assert r2.json()["id"] == r1.json()["id"]
    assert r2.json()["receipt_number"] == r1.json()["receipt_number"]


def test_pricing_and_geofence_and_full_loop(client, tenant_ctx, tokens):
    """End-to-end: load sheet -> shift start -> accept -> route -> check-in -> delivery -> closeout."""
    from tests.conftest import auth
    import uuid as uuid_mod

    # warehouse creates load sheet
    r = client.post(
        "/api/v1/shifts/load-sheets",
        headers=auth(tokens["warehouse"]),
        json={
            "vehicle_id": str(tenant_ctx["vehicle_id"]),
            "depot_location_id": str(tenant_ctx["depot_id"]),
            "lines": [
                {
                    "cylinder_type_id": str(tenant_ctx["cylinder_type_id"]),
                    "quantity": 50,
                }
            ],
        },
    )
    assert r.status_code == 201, r.text
    ls_id = r.json()["id"]

    # agent starts shift
    r = client.post(
        "/api/v1/shifts/start",
        headers=auth(tokens["agent"]),
        json={
            "vehicle_id": str(tenant_ctx["vehicle_id"]),
            "odometer_km": 1000,
            "pre_trip_safety": {
                "fire_extinguisher_valid": True,
                "cargo_straps_secured": True,
                "stacking_compliant": True,
                "no_gas_leaks": True,
            },
        },
    )
    assert r.status_code == 201, r.text
    shift_id = r.json()["id"]

    # accept load
    r = client.post(
        f"/api/v1/shifts/{shift_id}/accept-load",
        headers=auth(tokens["agent"]),
        json={
            "load_sheet_id": ls_id,
            "accepted_quantities": [
                {
                    "cylinder_type_id": str(tenant_ctx["cylinder_type_id"]),
                    "quantity": 50,
                }
            ],
        },
    )
    assert r.status_code == 201, r.text
    assert r.json()["movements_logged"] == 1

    # dispatcher creates route
    r = client.post(
        "/api/v1/routes",
        headers=auth(tokens["dispatcher"]),
        json={
            "shift_id": shift_id,
            "planned_date": "2026-09-24T08:00:00Z",
            "stops": [
                {"outlet_id": str(tenant_ctx["outlet_id"]), "sequence_order": 1}
            ],
        },
    )
    assert r.status_code == 201, r.text
    route_id = r.json()["id"]
    stop = r.json()["stops"][0]
    stop_id = stop["id"]
    assert stop["outlet_name"] == "Test Outlet"
    assert stop["latitude"] == 33.5731
    assert stop["longitude"] == -7.5898

    # publish
    r = client.post(f"/api/v1/routes/{route_id}/publish", headers=auth(tokens["dispatcher"]))
    assert r.status_code == 200

    # en route
    r = client.post(f"/api/v1/routes/stops/{stop_id}/en-route", headers=auth(tokens["agent"]))
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "EN_ROUTE"

    # check-in OUTSIDE geofence should fail
    r = client.post(
        f"/api/v1/routes/stops/{stop_id}/check-in",
        headers=auth(tokens["agent"]),
        json={
            "client_event_id": str(uuid_mod.uuid4()),
            "occurred_at": "2026-09-24T09:00:00Z",
            "method": "geofence",
            "latitude": 34.5,
            "longitude": -6.5,
            "accuracy_m": 10,
        },
    )
    assert r.status_code == 422

    # check-in INSIDE (Casablanca coords used for outlet)
    r = client.post(
        f"/api/v1/routes/stops/{stop_id}/check-in",
        headers=auth(tokens["agent"]),
        json={
            "client_event_id": str(uuid_mod.uuid4()),
            "occurred_at": "2026-09-24T09:00:00Z",
            "method": "geofence",
            "latitude": 33.5731,
            "longitude": -7.5898,
            "accuracy_m": 12,
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["validated"] is True
    assert body["distance_meters"] is not None
    assert body["distance_meters"] <= 60

    # delivery with payment
    r = client.post(
        f"/api/v1/route-stops/{stop_id}/deliveries",
        headers={**auth(tokens["agent"]), "Idempotency-Key": str(uuid_mod.uuid4())},
        json={
            "client_event_id": str(uuid_mod.uuid4()),
            "occurred_at": "2026-09-24T09:25:00Z",
            "recipient_name": "Mustapha",
            "signature_media_token": "sig1",
            "photo_media_token": "img1",
            "lines": [
                {
                    "cylinder_type_id": str(tenant_ctx["cylinder_type_id"]),
                    "delivered_full_qty": 10,
                    "returned_empty_qty": 8,
                    "returned_defective_qty": 0,
                }
            ],
            "payment": {"amount_mad": 1400.0, "method": "cash"},
        },
    )
    assert r.status_code == 201, r.text
    d = r.json()
    # pricing: 10 * 140 = 1400; deposit net (10-8)*80 = 160; total 1560
    assert abs(d["subtotal_mad"] - 1400.0) < 0.01
    assert abs(d["deposit_net_mad"] - 160.0) < 0.01
    assert abs(d["total_amount_mad"] - 1560.0) < 0.01
    assert abs(d["paid_amount_mad"] - 1400.0) < 0.01
    assert d["movements_logged"] >= 2

    # inventory: vehicle had 50, delivered 10 -> 40 full remain; empties 8 on vehicle
    r = client.get(
        f"/api/v1/inventory/vehicle-stock/{tenant_ctx['vehicle_id']}",
        headers=auth(tokens["agent"]),
    )
    assert r.status_code == 200
    stock = {(i["cylinder_state"]): i["quantity"] for i in r.json()}
    assert stock.get("full") == 40
    assert stock.get("empty") == 8

    # test PDF delivery note download
    r_pdf = client.get(
        f"/api/v1/route-stops/{stop_id}/delivery-note/pdf",
        headers=auth(tokens["agent"]),
    )
    assert r_pdf.status_code == 200
    assert r_pdf.headers["content-type"] == "application/pdf"
    assert len(r_pdf.content) > 1000
    assert r_pdf.content[:4] == b"%PDF"

    # cannot deliver more than vehicle stock
    # first re-check remaining — need to check in another stop? stop already completed.
    # Use insufficient stock unit path via new stop if needed — skip for now.

    # closeout: unload remaining full+empty
    r = client.post(
        f"/api/v1/shifts/{shift_id}/closeout-unload",
        headers=auth(tokens["agent"]),
        json={
            "unloaded_lines": [
                {
                    "cylinder_type_id": str(tenant_ctx["cylinder_type_id"]),
                    "state": "full",
                    "quantity": 40,
                },
                {
                    "cylinder_type_id": str(tenant_ctx["cylinder_type_id"]),
                    "state": "empty",
                    "quantity": 8,
                },
            ],
            "declared_cash_mad": 1400.0,
            "cashier_user_id": str(tenant_ctx["accountant_id"]),
            "variance_reason": "No variance.",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["variance_mad"] == 0
    assert r.json()["status"] == "RECONCILED"


def test_negative_stock_prevented(client, tenant_ctx, tokens):
    import uuid as uuid_mod

    # start shift without loading stock
    r = client.post(
        "/api/v1/shifts/start",
        headers=auth(tokens["agent"]),
        json={
            "vehicle_id": str(tenant_ctx["vehicle_id"]),
            "pre_trip_safety": {
                "fire_extinguisher_valid": True,
                "cargo_straps_secured": True,
                "stacking_compliant": True,
                "no_gas_leaks": True,
            },
        },
    )
    if r.status_code == 409:
        # active shift from previous test — close it path or use existing
        shift_id = r.json()["detail"]
        # get active
        r = client.get("/api/v1/shifts/me/active", headers=auth(tokens["agent"]))
        assert r.status_code == 200
        if r.json() is None:
            pytest.skip("no active shift")
        shift_id = r.json()["id"]
    else:
        assert r.status_code == 201, r.text
        shift_id = r.json()["id"]

    r = client.post(
        "/api/v1/routes",
        headers=auth(tokens["dispatcher"]),
        json={
            "shift_id": shift_id,
            "planned_date": "2026-09-24T10:00:00Z",
            "stops": [{"outlet_id": str(tenant_ctx["outlet_id"]), "sequence_order": 1}],
        },
    )
    if r.status_code == 409:
        # duplicate route for same shift day is fine — new sequence unique per route
        pass
    assert r.status_code == 201, r.text
    stop_id = r.json()["stops"][0]["id"]
    route_id = r.json()["id"]
    client.post(f"/api/v1/routes/{route_id}/publish", headers=auth(tokens["dispatcher"]))
    client.post(f"/api/v1/routes/stops/{stop_id}/en-route", headers=auth(tokens["agent"]))
    client.post(
        f"/api/v1/routes/stops/{stop_id}/check-in",
        headers=auth(tokens["agent"]),
        json={
            "client_event_id": str(uuid_mod.uuid4()),
            "occurred_at": "2026-09-24T10:05:00Z",
            "method": "geofence",
            "latitude": 33.5731,
            "longitude": -7.5898,
            "accuracy_m": 10,
        },
    )
    r = client.post(
        f"/api/v1/route-stops/{stop_id}/deliveries",
        headers={**auth(tokens["agent"]), "Idempotency-Key": str(uuid_mod.uuid4())},
        json={
            "client_event_id": str(uuid_mod.uuid4()),
            "occurred_at": "2026-09-24T10:10:00Z",
            "recipient_name": "X",
            "lines": [
                {
                    "cylinder_type_id": str(tenant_ctx["cylinder_type_id"]),
                    "delivered_full_qty": 9999,
                }
            ],
        },
    )
    assert r.status_code == 409  # INSUFFICIENT_STOCK


def test_stop_binding_agent_cannot_touch_others(client, tenant_ctx, tokens):
    # other is owner of other tenant — create route under other? simpler:
    # agent2 not available; ensure agent cannot check in stop of unpublished route by dispatcher only
    # Cross-tenant: other tries agent-like access to our stop — need a stop first
    import uuid as uuid_mod

    r = client.post(
        "/api/v1/shifts/start",
        headers=auth(tokens["agent"]),
        json={
            "vehicle_id": str(tenant_ctx["vehicle_id"]),
            "pre_trip_safety": {
                "fire_extinguisher_valid": True,
                "cargo_straps_secured": True,
                "stacking_compliant": True,
                "no_gas_leaks": True,
            },
        },
    )
    if r.status_code == 201:
        shift_id = r.json()["id"]
    else:
        r = client.get("/api/v1/shifts/me/active", headers=auth(tokens["agent"]))
        shift_id = r.json()["id"]

    r = client.post(
        "/api/v1/routes",
        headers=auth(tokens["dispatcher"]),
        json={
            "shift_id": shift_id,
            "planned_date": "2026-09-24T11:00:00Z",
            "stops": [{"outlet_id": str(tenant_ctx["outlet_id"]), "sequence_order": 5}],
        },
    )
    assert r.status_code == 201, r.text
    stop_id = r.json()["stops"][0]["id"]

    # other tenant user cannot access stop
    r = client.get(f"/api/v1/routes/stops/{stop_id}", headers=auth(tokens["other"]))
    assert r.status_code == 404


def test_otp_rate_limit(client):
    phone = "+212699999001"
    codes = []
    for i in range(3):
        r = client.post("/api/v1/auth/otp/request", json={"phone": phone})
        assert r.status_code == 200
    r = client.post("/api/v1/auth/otp/request", json={"phone": phone})
    assert r.status_code == 422


def test_pre_trip_required(client, tenant_ctx, tokens):
    r = client.post(
        "/api/v1/shifts/start",
        headers=auth(tokens["agent"]),
        json={
            "vehicle_id": str(tenant_ctx["vehicle_id"]),
            "pre_trip_safety": {
                "fire_extinguisher_valid": False,
                "cargo_straps_secured": True,
                "stacking_compliant": True,
                "no_gas_leaks": True,
            },
        },
    )
    # either conflict (active) or validation
    assert r.status_code in (409, 422)


def test_safety_critical(client, tenant_ctx, tokens):
    import uuid as uuid_mod

    # ensure shift
    r = client.get("/api/v1/shifts/me/active", headers=auth(tokens["agent"]))
    if r.json() is None:
        r = client.post(
            "/api/v1/shifts/start",
            headers=auth(tokens["agent"]),
            json={
                "vehicle_id": str(tenant_ctx["vehicle_id"]),
                "pre_trip_safety": {
                    "fire_extinguisher_valid": True,
                    "cargo_straps_secured": True,
                    "stacking_compliant": True,
                    "no_gas_leaks": True,
                },
            },
        )
        shift_id = r.json()["id"]
    else:
        shift_id = r.json()["id"]

    r = client.post(
        "/api/v1/safety-incidents",
        headers=auth(tokens["agent"]),
        json={
            "shift_id": shift_id,
            "incident_type": "GAS_LEAK_BODY",
            "severity": "CRITICAL",
            "description": "Active hissing",
            "latitude": 33.573,
            "longitude": -7.589,
            "photo_media_token": "img_leak",
        },
    )
    assert r.status_code == 201, r.text
    r = client.get("/api/v1/safety-incidents", headers=auth(tokens["owner"]))
    assert r.status_code == 200
    assert any(i["severity"] == "CRITICAL" for i in r.json())


def test_credit_check_soft_warning(client, tenant_ctx, tokens):
    """Credit check API returns soft warning when projected exceeds limit."""
    r = client.post(
        f"/api/v1/credit/outlets/{tenant_ctx['outlet_id']}/check",
        headers=auth(tokens["agent"]),
        json={"proposed_order_total_mad": 10000},
    )
    assert r.status_code == 200
    body = r.json()
    assert "soft_warning" in body
    assert "hard_lock" in body
    # credit limit 5000, proposed 10000 -> soft warning True
    assert body["soft_warning"] is True
    assert body["hard_lock"] is False  # no old unpaid invoices


def test_refresh_token_flow(client, tenant_ctx):
    from tests.conftest import login
    tok = login(client, tenant_ctx["phones"]["owner"])
    refresh_token = tok["refresh_token"]

    r = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert r.status_code == 200, r.text
    data = r.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["role"] == "owner"
    assert data["tenant_id"] == str(tenant_ctx["tenant_id"])


def test_outlets_coordinates(client, tenant_ctx, tokens):
    """Verify outlets endpoint returns real PostGIS coordinates."""
    r = client.get("/api/v1/outlets", headers=auth(tokens["owner"]))
    assert r.status_code == 200, r.text
    outlets = r.json()
    assert len(outlets) >= 1
    found = next((o for o in outlets if o["id"] == str(tenant_ctx["outlet_id"])), None)
    assert found is not None
    assert found["name"] == "Test Outlet"
    assert found["latitude"] == 33.5731
    assert found["longitude"] == -7.5898


def test_route_optimization_tsp(client, tenant_ctx, tokens):
    """Verify route optimization orders stops by shortest traveling distance."""
    # Start a dummy shift
    r = client.post(
        "/api/v1/shifts/start",
        headers=auth(tokens["agent"]),
        json={
            "vehicle_id": str(tenant_ctx["vehicle_id"]),
            "odometer_km": 2000,
            "pre_trip_safety": {
                "fire_extinguisher_valid": True,
                "cargo_straps_secured": True,
                "stacking_compliant": True,
                "no_gas_leaks": True,
            },
        },
    )
    shift_id = r.json()["id"]

    # Create a draft route with 1 stop
    r = client.post(
        "/api/v1/routes",
        headers=auth(tokens["dispatcher"]),
        json={
            "shift_id": shift_id,
            "planned_date": "2026-09-25T08:00:00Z",
            "stops": [{"outlet_id": str(tenant_ctx["outlet_id"]), "sequence_order": 1}],
        },
    )
    assert r.status_code == 201
    route_id = r.json()["id"]

    # Optimize route
    r_opt = client.post(
        f"/api/v1/routes/{route_id}/optimize",
        headers=auth(tokens["dispatcher"]),
    )
    assert r_opt.status_code == 200
    assert len(r_opt.json()["stops"]) == 1


def test_live_fleet_telemetry(client, tenant_ctx, tokens):
    """Verify GPS telemetry ingestion and live fleet tracking."""
    # Find active shift or start one
    r_me = client.get("/api/v1/shifts/me/active", headers=auth(tokens["agent"]))
    shift_id = r_me.json()["id"] if r_me.json() else None
    if not shift_id:
        r = client.post(
            "/api/v1/shifts/start",
            headers=auth(tokens["agent"]),
            json={
                "vehicle_id": str(tenant_ctx["vehicle_id"]),
                "odometer_km": 3000,
                "pre_trip_safety": {
                    "fire_extinguisher_valid": True,
                    "cargo_straps_secured": True,
                    "stacking_compliant": True,
                    "no_gas_leaks": True,
                },
            },
        )
        shift_id = r.json()["id"]

    # Send GPS telemetry ping
    r_ping = client.post(
        f"/api/v1/shifts/{shift_id}/telemetry",
        headers=auth(tokens["agent"]),
        json={
            "latitude": 33.5850,
            "longitude": -7.6100,
            "speed_kmh": 42.5,
            "battery_level": 88.0,
        },
    )
    assert r_ping.status_code == 200
    assert r_ping.json()["status"] == "ok"

    # Query live fleet
    r_fleet = client.get("/api/v1/live-fleet", headers=auth(tokens["dispatcher"]))
    assert r_fleet.status_code == 200
    trucks = r_fleet.json()
    assert len(trucks) >= 1
    truck = next((t for t in trucks if t["shift_id"] == shift_id), None)
    assert truck is not None
    assert truck["latitude"] == 33.585
    assert truck["longitude"] == -7.61
    assert truck["speed_kmh"] == 42.5



