import uuid
import logging
import pytest
from decimal import Decimal

# Configure logging to see the prints during pytest execution
logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

def test_end_to_end_simulation(client, tenant_ctx, tokens):
    logger.info("\n=== DÉBUT DE LA SIMULATION END-TO-END ===")
    
    owner_tok = tokens["owner"]
    agent_tok = tokens["agent"]
    wh_tok = tokens["warehouse"]
    disp_tok = tokens["dispatcher"]
    
    def auth_headers(tok):
        return {"Authorization": f"Bearer {tok['access_token']}"}

    depot_id = tenant_ctx["depot_id"]
    vehicle_id = tenant_ctx["vehicle_id"]
    ct_id = tenant_ctx["cylinder_type_id"]
    outlet_id = tenant_ctx["outlet_id"]
    
    logger.info("\n--- [1] Réception Usine (Magasinier) ---")
    r = client.post("/api/v1/inventory/factory-receipt", json={
        "depot_location_id": str(depot_id),
        "lines": [{"cylinder_type_id": str(ct_id), "quantity": 1000}]
    }, headers=auth_headers(wh_tok))
    assert r.status_code == 201
    logger.info("-> 1000 bouteilles pleines ajoutées au Dépôt Central.")

    logger.info("\n--- [2] Démarrage du Shift & Sélection Camion (Chauffeur) ---")
    r = client.post("/api/v1/shifts/start", json={
        "vehicle_id": str(vehicle_id),
        "odometer_km": 12500,
        "pre_trip_safety": {
            "fire_extinguisher_valid": True,
            "cargo_straps_secured": True,
            "stacking_compliant": True,
            "no_gas_leaks": True
        }
    }, headers=auth_headers(agent_tok))
    assert r.status_code == 201
    shift_id = r.json()["id"]
    logger.info(f"-> Shift actif créé (ID: {shift_id}).")

    logger.info("\n--- [3] Feuille de Chargement ---")
    r = client.post("/api/v1/shifts/load-sheets", json={
        "shift_id": shift_id,
        "vehicle_id": str(vehicle_id),
        "depot_location_id": str(depot_id),
        "lines": [{"cylinder_type_id": str(ct_id), "quantity": 150}]
    }, headers=auth_headers(wh_tok))
    assert r.status_code == 201
    ls_id = r.json()["id"]
    logger.info("-> Magasinier : Feuille de chargement (150 bouteilles) émise.")

    r = client.post(f"/api/v1/shifts/{shift_id}/accept-load", json={
        "load_sheet_id": ls_id,
        "accepted_quantities": [{"cylinder_type_id": str(ct_id), "quantity": 150}]
    }, headers=auth_headers(agent_tok))
    assert r.status_code == 201
    logger.info("-> Chauffeur : Chargement de 150 bouteilles accepté sur le camion.")

    logger.info("\n--- [4] Tournée : Attribution et Navigation ---")
    r = client.post("/api/v1/routes", headers=auth_headers(disp_tok), json={
        "shift_id": shift_id,
        "planned_date": "2026-10-09",
        "stops": [{"outlet_id": str(outlet_id), "sequence_order": 1}]
    })
    assert r.status_code == 201, r.text
    route_id = r.json()["id"]
    stop_id = r.json()["stops"][0]["id"]
    
    r = client.post(f"/api/v1/routes/{route_id}/publish", headers=auth_headers(disp_tok))
    assert r.status_code == 200, r.text
    logger.info("-> Dispatcher : Tournée créée et publiée.")
    
    r = client.post(f"/api/v1/routes/stops/{stop_id}/en-route", headers=auth_headers(agent_tok))
    assert r.status_code == 200, r.text
    
    r = client.post(f"/api/v1/routes/stops/{stop_id}/check-in", headers=auth_headers(agent_tok), json={
        "client_event_id": str(uuid.uuid4()),
        "occurred_at": "2026-10-09T09:00:00Z",
        "method": "geofence",
        "latitude": 33.5731,
        "longitude": -7.5898,
        "accuracy_m": 10
    })
    assert r.status_code == 200, r.text
    logger.info("-> Chauffeur : Check-in GPS validé sur le point de vente.")

    logger.info("\n--- [5] Livraison Point de Vente ---")
    client_event_id = str(uuid.uuid4())
    r = client.post(f"/api/v1/route-stops/{stop_id}/deliveries", headers={
        **auth_headers(agent_tok),
        "Idempotency-Key": client_event_id
    }, json={
        "client_event_id": client_event_id,
        "occurred_at": "2026-10-09T10:00:00Z",
        "recipient_name": "Gérant Hanout",
        "lines": [{
            "cylinder_type_id": str(ct_id),
            "delivered_full_qty": 40,
            "returned_empty_qty": 38,
            "returned_defective_qty": 2
        }],
        "payment": {
            "amount_mad": 5600.0,
            "method": "cash"
        }
    })
    assert r.status_code == 201, r.text
    logger.info("-> Chauffeur : Livraison enregistrée. Encaissé : 5600 MAD.")

    logger.info("\n--- [6] Retour Dépôt & Réconciliation ---")
    r = client.post(f"/api/v1/shifts/{shift_id}/closeout-unload", json={
        "cashier_user_id": str(tenant_ctx["warehouse_id"]),
        "declared_cash_mad": 5600.0,
        "unloaded_lines": [
            {"cylinder_type_id": str(ct_id), "state": "full", "quantity": 110},
            {"cylinder_type_id": str(ct_id), "state": "empty", "quantity": 38},
            {"cylinder_type_id": str(ct_id), "state": "defective", "quantity": 2}
        ]
    }, headers=auth_headers(wh_tok))
    assert r.status_code == 200, r.text
    res = r.json()
    logger.info("-> Magasinier / Caisse : Retour camion traité.")
    logger.info(f"   - Statut final du shift : {res['status']}")
    logger.info(f"   - Écart de caisse (Variance) : {res['variance_mad']} MAD")
    
    logger.info("\n=== SIMULATION TERMINÉE AVEC SUCCÈS ===")
