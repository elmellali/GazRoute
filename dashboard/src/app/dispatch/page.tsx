"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import ForbiddenError from "@/components/ForbiddenError";

const DispatchMap = dynamic(() => import("@/components/DispatchMap"), { ssr: false });

type Stop = {
  id: string;
  outlet_id: string;
  sequence_order: number;
  status: string;
  exception_reason?: string | null;
};

type Route = {
  id: string;
  status: string;
  stops: Stop[];
  shift_id: string;
};

type LiveVehicle = {
  shift_id: string;
  agent_name: string;
  agent_phone: string;
  plate_number: string;
  vehicle_model?: string | null;
  latitude: number;
  longitude: number;
  speed_kmh?: number | null;
  last_ping_at: string;
  status: string;
};

type Shift = {
  id: string;
  agent_id: string;
  vehicle_id: string;
  status: string;
  started_at: string;
  ended_at?: string | null;
  odometer_km?: number | null;
};

type User = {
  id: string;
  phone: string;
  full_name?: string | null;
  role: string;
  is_active?: boolean;
};

type Vehicle = {
  id: string;
  plate_number: string;
  model: string;
  max_payload_kg: number;
};

type Loc = {
  id: string;
  name: string;
  type: string;
};

export default function DispatchPage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [fleet, setFleet] = useState<LiveVehicle[]>([]);
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [locs, setLocs] = useState<Loc[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const { t, te } = useI18n();

  // Shift Modal State
  const [showShiftModal, setShowShiftModal] = useState(false);
  const [shiftAgentId, setShiftAgentId] = useState("");
  const [shiftVehicleId, setShiftVehicleId] = useState("");
  const [shiftDepotId, setShiftDepotId] = useState("");
  const [shiftOdometer, setShiftOdometer] = useState(0);
  const [isSubmittingShift, setIsSubmittingShift] = useState(false);

  async function loadData() {
    try {
      const [r, f, s, u, v, l] = await Promise.all([
        api<Route[]>("/api/v1/routes").catch(() => []),
        api<LiveVehicle[]>("/api/v1/live-fleet").catch(() => []),
        api<Shift[]>("/api/v1/shifts").catch(() => []),
        api<User[]>("/api/v1/users").catch(() => []),
        api<Vehicle[]>("/api/v1/vehicles").catch(() => []),
        api<Loc[]>("/api/v1/inventory/locations").catch(() => []),
      ]);
      setRoutes(r);
      setFleet(f);
      setShifts(s);
      setUsers(u);
      setVehicles(v);
      setLocs(l);

      const drivers = u.filter((x) => x.role === "agent");
      if (drivers.length > 0) setShiftAgentId((prev) => prev || drivers[0].id);
      else if (u.length > 0) setShiftAgentId((prev) => prev || u[0].id);

      if (v.length > 0) setShiftVehicleId((prev) => prev || v[0].id);
      const depots = l.filter((x) => x.type === "depot");
      if (depots.length > 0) setShiftDepotId((prev) => prev || depots[0].id);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    loadData();
    const id = setInterval(loadData, 10000);
    return () => clearInterval(id);
  }, []);

  async function handleStartShift(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmittingShift(true);

    try {
      if (!shiftAgentId || !shiftVehicleId) {
        throw new Error("Veuillez sélectionner un chauffeur et un véhicule.");
      }

      await api("/api/v1/shifts", {
        method: "POST",
        body: JSON.stringify({
          agent_id: shiftAgentId,
          vehicle_id: shiftVehicleId,
          depot_location_id: shiftDepotId || undefined,
          odometer_km: Number(shiftOdometer) || 0,
        }),
      });

      setSuccess("Shift démarré avec succès ! Le chauffeur peut désormais recevoir sa tournée.");
      setShowShiftModal(false);
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmittingShift(false);
    }
  }

  async function handleCloseShift(shiftId: string) {
    if (!confirm("Confirmer la clôture de ce shift opérationnel ?")) return;
    setError("");
    setSuccess("");

    try {
      await api(`/api/v1/shifts/${shiftId}/close`, { method: "POST" });
      setSuccess("Shift clôturé avec succès.");
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  function getAgentName(agentId: string) {
    const u = users.find((x) => x.id === agentId);
    return u ? (u.full_name ? `${u.full_name} (${u.phone})` : u.phone) : agentId.slice(0, 8);
  }

  function getVehiclePlate(vehicleId: string) {
    const v = vehicles.find((x) => x.id === vehicleId);
    return v ? `${v.plate_number} (${v.model || "Camion"})` : vehicleId.slice(0, 8);
  }

  const allStops = routes.flatMap((r) => r.stops.map((s) => ({ ...s, routeId: r.id })));
  const counts = allStops.reduce<Record<string, number>>((acc, s) => {
    acc[s.status] = (acc[s.status] || 0) + 1;
    return acc;
  }, {});

  const activeShiftsCount = shifts.filter((s) => s.status === "ACTIVE").length;

  if (error && error.toLowerCase().includes("not permitted")) {
    return <ForbiddenError error={error} />;
  }

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>📡</span>
            <span>{t("dispatchTitle")}</span>
          </h1>
          <p className="page-sub">{t("dispatchSub")}</p>
        </div>
        <div className="row">
          <button
            type="button"
            className="btn sm"
            onClick={() => setShowShiftModal(true)}
          >
            <span>＋</span>
            <span>Démarrer un Shift</span>
          </button>
          <span className="badge info">
            <span>● GPS RADAR ACTIF</span>
          </span>
          <span className="badge neutral">
            <span>POLLING 10s</span>
          </span>
        </div>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}
      {success && <div className="alert-banner success">✓ {success}</div>}

      {/* Asymmetric Telemetry Hero Header */}
      <section className="editorial-grid-tri" aria-label="Télémétrie en direct">
        <div className="kpi-card" style={{ borderLeft: "3px solid var(--signal-info)" }}>
          <div className="kpi-label">
            <span>🚛</span> Quarts / Shifts Actifs
          </div>
          <div className="kpi-val" style={{ color: "var(--signal-info)" }}>
            {activeShiftsCount} <span style={{ fontSize: "1rem", color: "var(--ink-muted)", fontWeight: 500 }}>en cours</span>
          </div>
          <small className="muted" style={{ fontSize: "0.78rem" }}>{fleet.length} camions émettent des pings GPS</small>
        </div>

        <div className="kpi-card" style={{ borderLeft: "3px solid var(--signal-ok)" }}>
          <div className="kpi-label">
            <span>✓</span> Arrêts Complétés
          </div>
          <div className="kpi-val" style={{ color: "var(--signal-ok)" }}>
            {counts["COMPLETED"] || 0} / {allStops.length}
          </div>
          <small className="muted" style={{ fontSize: "0.78rem" }}>Progression globale de livraison</small>
        </div>

        <div className={`kpi-card ${counts["EXCEPTION"] ? "alert-high" : ""}`}>
          <div className="kpi-label">
            <span>⚠️</span> Exceptions Signalées
          </div>
          <div className="kpi-val" style={{ color: counts["EXCEPTION"] ? "var(--signal-danger)" : "var(--signal-ok)" }}>
            {counts["EXCEPTION"] || 0}
          </div>
          <small className="muted" style={{ fontSize: "0.78rem" }}>Clients fermés ou accès refusé</small>
        </div>
      </section>

      {/* Tactical Map Container (Focal Point) */}
      <div className="panel map-box" style={{ marginBottom: "var(--space-20)", height: 500 }}>
        <DispatchMap stops={allStops} vehicles={fleet} />
      </div>

      {/* Gestion des Shifts Opérationnels */}
      <div className="panel" style={{ marginBottom: "var(--space-20)" }}>
        <div className="panel-header">
          <h2 className="panel-title">
            <span>⏱️</span> Quarts de Travail & Shifts Chauffeurs ({shifts.length})
          </h2>
          <button
            type="button"
            className="btn sm"
            onClick={() => setShowShiftModal(true)}
          >
            <span>＋</span>
            <span>Démarrer un Shift</span>
          </button>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>ID Shift</th>
                <th>Chauffeur (Agent)</th>
                <th>Camion Assigné</th>
                <th>Démarré le</th>
                <th>Statut</th>
                <th style={{ textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {shifts.map((s) => (
                <tr key={s.id}>
                  <td><code className="mono">{s.id.slice(0, 8)}</code></td>
                  <td style={{ fontWeight: 700, color: "var(--ink-primary)" }}>
                    {getAgentName(s.agent_id)}
                  </td>
                  <td>
                    <span style={{ fontWeight: 600 }}>{getVehiclePlate(s.vehicle_id)}</span>
                  </td>
                  <td>
                    <code className="mono">{String(s.started_at).slice(0, 16).replace("T", " ")}</code>
                  </td>
                  <td>
                    <span
                      className={`badge ${
                        s.status === "ACTIVE"
                          ? "ok"
                          : s.status === "CLOSED"
                            ? "neutral"
                            : "warn"
                      }`}
                    >
                      <span>
                        {s.status === "ACTIVE" ? "● EN COURS" : s.status}
                      </span>
                    </span>
                  </td>
                  <td style={{ textAlign: "right" }}>
                    {s.status === "ACTIVE" && (
                      <button
                        type="button"
                        className="btn secondary sm"
                        onClick={() => handleCloseShift(s.id)}
                      >
                        Clôturer
                      </button>
                    )}
                  </td>
                </tr>
              ))}
              {shifts.length === 0 && (
                <tr>
                  <td colSpan={6} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                    Aucun shift enregistré. Cliquez sur "Démarrer un Shift" pour ouvrir le quart d'un chauffeur.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Structured Manifest Table */}
      <div className="panel">
        <div className="panel-header">
          <h2 className="panel-title">
            <span>📋</span> Journal de Suivi des Arrêts en Temps Réel ({allStops.length})
          </h2>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t("stop")}</th>
                <th>{t("seq")}</th>
                <th>{t("status")}</th>
                <th>{t("exceptionCol")}</th>
              </tr>
            </thead>
            <tbody>
              {allStops.map((s) => (
                <tr key={s.id}>
                  <td><code className="mono">{s.outlet_id.slice(0, 10)}</code></td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>#{s.sequence_order}</td>
                  <td>
                    <span
                      className={`badge ${
                        s.status === "COMPLETED"
                          ? "ok"
                          : s.status === "EXCEPTION"
                            ? "danger"
                          : s.status === "ARRIVED" || s.status === "IN_SERVICE"
                            ? "info"
                            : "warn"
                      }`}
                    >
                      <span>
                        {s.status === "COMPLETED" ? "● " : s.status === "EXCEPTION" ? "▲ " : "■ "}
                        {te(s.status)}
                      </span>
                    </span>
                  </td>
                  <td>{s.exception_reason ? <span style={{ color: "var(--signal-danger)", fontWeight: 600 }}>{s.exception_reason}</span> : <span className="muted">—</span>}</td>
                </tr>
              ))}
              {allStops.length === 0 && (
                <tr>
                  <td colSpan={4} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                    Aucun arrêt en cours d'exécution.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Démarrage Shift */}
      {showShiftModal && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content" style={{ maxWidth: 520 }}>
            <div className="panel-header">
              <h2 className="panel-title">
                <span>⏱️</span> Démarrer un Quart de Travail (Shift)
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowShiftModal(false)}>✕</button>
            </div>

            <form onSubmit={handleStartShift}>
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
                <div>
                  <label className="form-label">Chauffeur / Livreur (Agent) *</label>
                  <select
                    className="input"
                    value={shiftAgentId}
                    onChange={(e) => setShiftAgentId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un chauffeur --</option>
                    {users
                      .filter((u) => u.is_active !== false)
                      .map((u) => (
                        <option key={u.id} value={u.id}>
                          {u.full_name ? `${u.full_name} · ${u.phone}` : u.phone} ({u.role})
                        </option>
                      ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">Camion Assigné *</label>
                  <select
                    className="input"
                    value={shiftVehicleId}
                    onChange={(e) => setShiftVehicleId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un camion --</option>
                    {vehicles.map((v) => (
                      <option key={v.id} value={v.id}>
                        {v.plate_number} · {v.model || "Camion"} (Max: {v.max_payload_kg} kg)
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">Dépôt de Départ (Optionnel)</label>
                  <select
                    className="input"
                    value={shiftDepotId}
                    onChange={(e) => setShiftDepotId(e.target.value)}
                  >
                    <option value="">-- Dépôt par défaut --</option>
                    {locs
                      .filter((l) => l.type === "depot")
                      .map((l) => (
                        <option key={l.id} value={l.id}>
                          {l.name}
                        </option>
                      ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">Kilométrage Compteur Initial (km)</label>
                  <input
                    type="number"
                    min={0}
                    className="input"
                    placeholder="0"
                    value={shiftOdometer}
                    onChange={(e) => setShiftOdometer(Number(e.target.value))}
                  />
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowShiftModal(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn" disabled={isSubmittingShift}>
                  {isSubmittingShift ? "Ouverture..." : "✓ Démarrer le Shift"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
