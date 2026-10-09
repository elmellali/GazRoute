import json
from uuid import UUID
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import Base, engine, get_db
from tests.conftest import login, auth

def run_simulation():
    client = TestClient(app)
    
    # Generate seed data by relying on the app's behavior or creating it
    # But wait, to be safe and autonomous, let's create a fresh tenant for the simulation.
    print("--- [1] Initialisation & Réception Usine ---")
    
    # 1. Create Tenant
    r = client.post("/api/v1/tenants", json={
        "company_name": "GazRoute Simulation",
        "phone": "+212600000123",
        "ice_number": "123456789"
    })
    tenant_id = r.json()["id"]
    print(f"Tenant créé : {tenant_id}")
    
    # 2. Create Owner User
    r = client.post("/auth/request-otp", json={"phone": "+212600000123"})
    r = client.post("/auth/verify-otp", json={"phone": "+212600000123", "otp_code": "0000"})
    owner_token = r.json()
    owner_auth = {"Authorization": f"Bearer {owner_token['access_token']}"}

    # 3. Create Warehouse, Driver, Depot, Vehicle, Cylinder Types, Outlet
    print("-> Création des entités de base...")
    
    wh_res = client.post("/api/v1/users", json={"phone": "+212600000999", "full_name": "Magasinier", "role": "warehouse"}, headers=owner_auth)
    wh_id = wh_res.json()["id"]
    
    driver_res = client.post("/api/v1/users", json={"phone": "+212600000888", "full_name": "Chauffeur", "role": "agent"}, headers=owner_auth)
    driver_id = driver_res.json()["id"]
    
    depot_res = client.post("/api/v1/inventory/locations", json={"name": "Dépôt Central", "type": "depot"}, headers=owner_auth)
    depot_id = depot_res.json()["id"]
    
    vehicle_res = client.post("/api/v1/vehicles", json={"plate_number": "123-A-50", "model": "Isuzu", "max_payload_kg": 3500}, headers=owner_auth)
    vehicle_id = vehicle_res.json()["id"]
    
    ct_res = client.post("/api/v1/cylinder-types", json={
        "gas_type": "butane",
        "size_kg": 12.0,
        "deposit_amount_mad": 120.0,
        "base_sale_price_mad": 40.0
    }, headers=owner_auth)
    ct_12kg_id = ct_res.json()["id"]
    
    outlet_res = client.post("/api/v1/outlets", json={
        "name": "Hanout Simulation",
        "contact_name": "Hamid",
        "phone": "+212611111111",
        "latitude": 33.5,
        "longitude": -7.5,
        "geofence_radius_m": 50,
        "credit_limit_mad": 1000
    }, headers=owner_auth)
    outlet_id = outlet_res.json()["id"]
    
    # 4. Factory Receipt (inject stock)
    print("-> Entrée de stock usine (1000 bouteilles pleines de 12kg)...")
    wh_login = login(client, "+212600000999")
    r = client.post("/api/v1/inventory/factory-receipt", json={
        "depot_location_id": depot_id,
        "lines": [{"cylinder_type_id": ct_12kg_id, "quantity": 1000}]
    }, headers=auth(wh_login))
    assert r.status_code == 201
    
    print("\n--- [2] Attribution & Démarrage du Shift (Mobile) ---")
    driver_login = login(client, "+212600000888")
    r = client.post("/api/v1/shifts/start", json={
        "vehicle_id": vehicle_id,
        "odometer_km": 15000,
        "pre_trip_safety": {
            "fire_extinguisher_valid": True,
            "cargo_straps_secured": True,
            "stacking_compliant": True,
            "no_gas_leaks": True
        }
    }, headers=auth(driver_login))
    assert r.status_code == 201
    shift_id = r.json()["id"]
    print(f"Shift actif : {shift_id}")
    
    print("\n--- [3] Feuille de Chargement ---")
    print("-> Création par le magasinier...")
    r = client.post("/api/v1/shifts/load-sheets", json={
        "shift_id": shift_id,
        "vehicle_id": vehicle_id,
        "depot_location_id": depot_id,
        "lines": [{"cylinder_type_id": ct_12kg_id, "quantity": 100}]
    }, headers=auth(wh_login))
    ls_id = r.json()["id"]
    
    print("-> Acceptation par le chauffeur...")
    r = client.post(f"/api/v1/shifts/{shift_id}/accept-load", json={
        "load_sheet_id": ls_id,
        "accepted_quantities": [{"cylinder_type_id": ct_12kg_id, "quantity": 100}]
    }, headers=auth(driver_login))
    assert r.status_code == 201
    print("Chargement de 100 bouteilles pleines confirmé dans le camion.")
    
    print("\n--- [4] Livraison Point de Vente ---")
    import uuid
    client_event_id = str(uuid.uuid4())
    r = client.post(f"/api/v1/route-stops/{outlet_id}/deliveries", headers={
        **auth(driver_login),
        "Idempotency-Key": client_event_id
    }, json={
        "client_event_id": client_event_id,
        "occurred_at": "2026-10-09T10:00:00Z",
        "recipient_name": "Hamid Gérant",
        "lines": [{
            "cylinder_type_id": ct_12kg_id,
            "delivered_full_qty": 20,
            "returned_empty_qty": 20,
            "returned_defective_qty": 0
        }],
        "payment": {
            "amount_mad": 800.0,
            "method": "cash"
        }
    })
    assert r.status_code == 201
    print("Livraison effectuée : 20 pleines livrées, 20 vides récupérées, paiement 800 MAD reçu.")
    
    print("\n--- [5] Retour Dépôt & Réconciliation ---")
    r = client.post(f"/api/v1/shifts/{shift_id}/closeout-unload", json={
        "cashier_user_id": wh_id,
        "declared_cash_mad": 800.0,
        "unloaded_lines": [
            {"cylinder_type_id": ct_12kg_id, "state": "full", "quantity": 80},
            {"cylinder_type_id": ct_12kg_id, "state": "empty", "quantity": 20}
        ]
    }, headers=auth(wh_login))
    assert r.status_code == 200
    res = r.json()
    print(f"Clôture réussie avec statut : {res['status']}")
    print(f"Variance caisse calculée : {res['variance_mad']} MAD")
    print("✅ Simulation de bout en bout validée avec succès !")

if __name__ == "__main__":
    run_simulation()
