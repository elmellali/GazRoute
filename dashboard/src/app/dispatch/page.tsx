"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";

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

export default function DispatchPage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [fleet, setFleet] = useState<LiveVehicle[]>([]);
  const [error, setError] = useState("");
  const { t, te } = useI18n();

  useEffect(() => {
    async function load() {
      try {
        const [r, f] = await Promise.all([
          api<Route[]>("/api/v1/routes"),
          api<LiveVehicle[]>("/api/v1/live-fleet").catch(() => []),
        ]);
        setRoutes(r);
        setFleet(f);
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    }
    load();
    const id = setInterval(load, 10000);
    return () => clearInterval(id);
  }, []);

  const allStops = routes.flatMap((r) => r.stops.map((s) => ({ ...s, routeId: r.id })));
  const counts = allStops.reduce<Record<string, number>>((acc, s) => {
    acc[s.status] = (acc[s.status] || 0) + 1;
    return acc;
  }, {});

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
          <span className="badge info">
            <span>● GPS RADAR ACTIF</span>
          </span>
          <span className="badge neutral">
            <span>POLLING 10s</span>
          </span>
        </div>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}

      {/* Asymmetric Telemetry Hero Header */}
      <section className="editorial-grid-tri" aria-label="Télémétrie en direct">
        <div className="kpi-card" style={{ borderLeft: "3px solid var(--signal-info)" }}>
          <div className="kpi-label">
            <span>🚛</span> Flotte Camions Connectée
          </div>
          <div className="kpi-val" style={{ color: "var(--signal-info)" }}>
            {fleet.length} <span style={{ fontSize: "1rem", color: "var(--ink-muted)", fontWeight: 500 }}>actifs</span>
          </div>
          <small className="muted" style={{ fontSize: "0.78rem" }}>Positions GPS rafraîchies</small>
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
    </>
  );
}

