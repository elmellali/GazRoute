"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import ForbiddenError from "@/components/ForbiddenError";

type Stop = {
  id: string;
  outlet_id: string;
  outlet_name?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  sequence_order: number;
  status: string;
};

type Route = {
  id: string;
  shift_id: string;
  status: string;
  planned_date: string;
  stops: Stop[];
};

type Outlet = { id: string; name: string; phone: string };
type Shift = { id: string; agent_id: string; vehicle_id: string; status: string; started_at: string };

export default function RoutesPage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState<Route | null>(null);

  // New Route Modal State
  const [showCreate, setShowCreate] = useState(false);
  const [newShiftId, setNewShiftId] = useState("");
  const [newDate, setNewDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [selectedOutletIds, setSelectedOutletIds] = useState<string[]>([]);
  const [creating, setCreating] = useState(false);

  // Add Stop State
  const [addStopOutletId, setAddStopOutletId] = useState("");
  const [addingStop, setAddingStop] = useState(false);

  const { t, te } = useI18n();

  async function load() {
    try {
      const [r, o, s] = await Promise.all([
        api<Route[]>("/api/v1/routes"),
        api<Outlet[]>("/api/v1/outlets"),
        api<Shift[]>("/api/v1/shifts").catch(() => []),
      ]);
      setRoutes(r);
      setOutlets(o);
      setShifts(s);
      if (s.length > 0 && !newShiftId) {
        setNewShiftId(s[0].id);
      }
      if (r.length > 0 && !selected) {
        setSelected(r[0]);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function publish(id: string) {
    try {
      await api(`/api/v1/routes/${id}/publish`, { method: "POST" });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  async function optimize(id: string) {
    try {
      const updated = await api<Route>(`/api/v1/routes/${id}/optimize`, { method: "POST" });
      setSelected(updated);
      setRoutes((prev) => prev.map((r) => (r.id === id ? updated : r)));
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  async function deleteRoute(id: string) {
    if (!confirm("Confirmer la suppression / annulation de cette tournée ?")) return;
    try {
      await api(`/api/v1/routes/${id}`, { method: "DELETE" });
      if (selected?.id === id) setSelected(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  async function removeStop(routeId: string, stopId: string) {
    if (!confirm("Retirer cet arrêt de la tournée ?")) return;
    try {
      const updated = await api<Route>(`/api/v1/routes/${routeId}/stops/${stopId}`, { method: "DELETE" });
      setSelected(updated);
      setRoutes((prev) => prev.map((r) => (r.id === routeId ? updated : r)));
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  function downloadBl(stopId: string) {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:8000";
    window.open(`${apiUrl}/api/v1/route-stops/${stopId}/delivery-note/pdf`, "_blank");
  }

  function outletName(id: string) {
    return outlets.find((o) => o.id === id)?.name || id.slice(0, 8);
  }

  function move(route: Route, stopId: string, dir: -1 | 1) {
    const stops = [...route.stops];
    const i = stops.findIndex((s) => s.id === stopId);
    const j = i + dir;
    if (i < 0 || j < 0 || j >= stops.length) return;
    [stops[i], stops[j]] = [stops[j], stops[i]];
    stops.forEach((s, idx) => (s.sequence_order = idx + 1));
    const updated = { ...route, stops };
    setSelected(updated);
    setRoutes((prev) => prev.map((r) => (r.id === route.id ? updated : r)));
  }

  async function handleCreateRoute(e: React.FormEvent) {
    e.preventDefault();
    if (!newShiftId) {
      setError("Veuillez sélectionner un shift de chauffeur");
      return;
    }
    if (selectedOutletIds.length === 0) {
      setError("Veuillez sélectionner au moins un point de vente");
      return;
    }
    setCreating(true);
    setError("");
    try {
      const created = await api<Route>("/api/v1/routes", {
        method: "POST",
        body: JSON.stringify({
          shift_id: newShiftId,
          planned_date: new Date(newDate + "T08:00:00Z").toISOString(),
          stops: selectedOutletIds.map((id, idx) => ({
            outlet_id: id,
            sequence_order: idx + 1,
          })),
        }),
      });
      setShowCreate(false);
      setSelectedOutletIds([]);
      await load();
      setSelected(created);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setCreating(false);
    }
  }

  async function handleAddStop(routeId: string) {
    if (!addStopOutletId) return;
    setAddingStop(true);
    setError("");
    try {
      const updated = await api<Route>(`/api/v1/routes/${routeId}/stops`, {
        method: "POST",
        body: JSON.stringify({
          outlet_id: addStopOutletId,
          sequence_order: 1,
        }),
      });
      setSelected(updated);
      setRoutes((prev) => prev.map((r) => (r.id === routeId ? updated : r)));
      setAddStopOutletId("");
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setAddingStop(false);
    }
  }

  function toggleOutletSelection(id: string) {
    setSelectedOutletIds((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
    );
  }
  if (error && error.toLowerCase().includes("not permitted")) {
    return <ForbiddenError error={error} />;
  }

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>🗺️</span>
            <span>{t("routesTitle")}</span>
          </h1>
          <p className="page-sub">{t("routesSub")}</p>
        </div>
        <button type="button" className="btn" onClick={() => setShowCreate(true)}>
          <span>＋</span>
          <span>Nouvelle Tournée</span>
        </button>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}

      {/* Modal / Card to Create a New Route */}
      {showCreate && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content" style={{ maxWidth: 720 }}>
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🚚</span> Planifier une Nouvelle Tournée
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowCreate(false)}>✕</button>
            </div>
            <form onSubmit={handleCreateRoute}>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-12)" }}>
                <div>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "var(--space-4)" }}>
                    <label className="form-label" style={{ margin: 0 }}>Shift Chauffeur Actif *</label>
                    <a
                      href="/dispatch"
                      className="btn secondary sm"
                      style={{ padding: "1px 6px", fontSize: "0.72rem", textDecoration: "none" }}
                    >
                      ＋ Démarrer un Shift
                    </a>
                  </div>
                  <select
                    className="input"
                    value={newShiftId}
                    onChange={(e) => setNewShiftId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un shift actif --</option>
                    {shifts.map((s) => (
                      <option key={s.id} value={s.id}>
                        Shift {s.id.slice(0, 8)} ({s.status}) · {new Date(s.started_at).toLocaleDateString()}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="form-label">Date Prévue *</label>
                  <input
                    type="date"
                    className="input"
                    value={newDate}
                    onChange={(e) => setNewDate(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div style={{ marginTop: "var(--space-16)" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "var(--space-8)" }}>
                  <label className="form-label" style={{ margin: 0 }}>
                    Points de Vente à Livrer ({selectedOutletIds.length} sélectionnés)
                  </label>
                  <div className="row">
                    <button
                      type="button"
                      className="btn secondary sm"
                      onClick={() => setSelectedOutletIds(outlets.slice(0, 8).map((o) => o.id))}
                    >
                      8 Premiers
                    </button>
                    <button
                      type="button"
                      className="btn secondary sm"
                      onClick={() => setSelectedOutletIds([])}
                    >
                      Effacer
                    </button>
                  </div>
                </div>

                <div
                  style={{
                    maxHeight: 220,
                    overflowY: "auto",
                    border: "1px solid var(--border-raw)",
                    background: "var(--bg-surface-2)",
                    padding: "var(--space-8)",
                    display: "grid",
                    gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
                    gap: "var(--space-8)",
                  }}
                >
                  {outlets.map((o) => {
                    const isChecked = selectedOutletIds.includes(o.id);
                    return (
                      <label
                        key={o.id}
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: "var(--space-8)",
                          padding: "var(--space-8)",
                          background: isChecked ? "var(--bg-active)" : "transparent",
                          border: isChecked ? "1px solid var(--accent)" : "1px solid transparent",
                          cursor: "pointer",
                        }}
                      >
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => toggleOutletSelection(o.id)}
                        />
                        <span style={{ fontSize: "0.82rem" }}>
                          <strong style={{ color: "var(--ink-primary)" }}>{o.name}</strong> <br />
                          <small className="muted">{o.phone}</small>
                        </span>
                      </label>
                    );
                  })}
                </div>
              </div>

              <div style={{ marginTop: "var(--space-20)", display: "flex", justifyContent: "flex-end", gap: "var(--space-12)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowCreate(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn" disabled={creating || !newShiftId || selectedOutletIds.length === 0}>
                  {creating ? "Création en cours..." : "✓ Créer & Valider la Tournée"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Asymmetric Split: Routes Register (Left) & Active Route Stop Sequence Focal Inspector (Right) */}
      <section className="editorial-grid-split">
        {/* Routes Ledger */}
        <div className="panel">
          <div className="panel-header">
            <h2 className="panel-title">
              <span>📋</span> Tournées Planifiées ({routes.length})
            </h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{t("date")}</th>
                  <th>{t("status")}</th>
                  <th>{t("stops")}</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {routes.map((r) => (
                  <tr key={r.id} className={selected?.id === r.id ? "selected-row" : ""}>
                    <td style={{ fontWeight: 600 }}>{new Date(r.planned_date).toLocaleDateString()}</td>
                    <td>
                      <span className={`badge ${r.status === "PUBLISHED" ? "ok" : "info"}`}>
                        {r.status === "PUBLISHED" ? "● " : "▲ "}
                        {te(r.status)}
                      </span>
                    </td>
                    <td>{r.stops.length} arrêts</td>
                    <td>
                      <div className="row">
                        <button
                          type="button"
                          className="btn secondary sm"
                          onClick={() => setSelected(r)}
                        >
                          {selected?.id === r.id ? "Actif" : t("open")}
                        </button>
                        {r.status === "DRAFT" && (
                          <>
                            <button
                              type="button"
                              className="btn sm"
                              onClick={() => publish(r.id)}
                            >
                              {t("publish")}
                            </button>
                            <button
                              type="button"
                              className="btn danger sm"
                              onClick={() => deleteRoute(r.id)}
                              title="Supprimer la tournée"
                            >
                              🗑️
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
                {routes.length === 0 && (
                  <tr>
                    <td colSpan={4} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                      {t("noRoutes")}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Selected Route Focal Cockpit & Sequence Timeline */}
        <div className="panel" style={{ borderLeft: "3px solid var(--accent)" }}>
          {selected ? (
            <>
              <div className="panel-header">
                <div>
                  <h2 className="panel-title">
                    <span>📍</span> Séquence Arrêts · {selected.id.slice(0, 8)}
                  </h2>
                  <p className="panel-sub">
                    Statut: <strong>{te(selected.status)}</strong> · {selected.stops.length} points de déchargement
                  </p>
                </div>
                {selected.status === "DRAFT" && (
                  <button
                    type="button"
                    className="btn secondary sm"
                    onClick={() => optimize(selected.id)}
                    title="Calculer l'ordre de passage optimal (TSP)"
                  >
                    ⚡ TSP Optimiser
                  </button>
                )}
              </div>

              {selected.status === "DRAFT" && (
                <div style={{ background: "var(--bg-surface-2)", border: "1px solid var(--border-raw)", padding: "var(--space-8)", marginBottom: "var(--space-12)", display: "flex", gap: "var(--space-8)" }}>
                  <select
                    className="input"
                    style={{ fontSize: "0.85rem" }}
                    value={addStopOutletId}
                    onChange={(e) => setAddStopOutletId(e.target.value)}
                  >
                    <option value="">-- Ajouter un point de vente à la séquence --</option>
                    {outlets
                      .filter((o) => !selected.stops.some((s) => s.outlet_id === o.id))
                      .map((o) => (
                        <option key={o.id} value={o.id}>
                          + {o.name}
                        </option>
                      ))}
                  </select>
                  <button
                    type="button"
                    className="btn sm"
                    disabled={!addStopOutletId || addingStop}
                    onClick={() => handleAddStop(selected.id)}
                  >
                    {addingStop ? "..." : "Ajouter"}
                  </button>
                </div>
              )}

              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>#</th>
                      <th>{t("outlet")}</th>
                      <th>{t("status")}</th>
                      <th>Ordre / BL</th>
                    </tr>
                  </thead>
                  <tbody>
                    {[...selected.stops]
                      .sort((a, b) => a.sequence_order - b.sequence_order)
                      .map((s) => (
                        <tr key={s.id}>
                          <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>{s.sequence_order}</td>
                          <td style={{ fontWeight: 600, color: "var(--ink-primary)" }}>{outletName(s.outlet_id)}</td>
                          <td>
                            <span className={`badge ${s.status === "COMPLETED" ? "ok" : "info"}`}>
                              {te(s.status)}
                            </span>
                          </td>
                          <td>
                            <div className="row">
                              {selected.status === "DRAFT" && (
                                <>
                                  <button type="button" className="btn secondary sm" onClick={() => move(selected, s.id, -1)}>
                                    ↑
                                  </button>
                                  <button type="button" className="btn secondary sm" onClick={() => move(selected, s.id, 1)}>
                                    ↓
                                  </button>
                                  <button
                                    type="button"
                                    className="btn danger sm"
                                    onClick={() => removeStop(selected.id, s.id)}
                                    title="Retirer cet arrêt"
                                  >
                                    ✕
                                  </button>
                                </>
                              )}
                              {s.status === "COMPLETED" && (
                                <button
                                  type="button"
                                  className="btn secondary sm"
                                  onClick={() => downloadBl(s.id)}
                                >
                                  📄 e-BL
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            </>
          ) : (
            <p className="muted" style={{ padding: "var(--space-24)", textAlign: "center" }}>
              Sélectionnez une tournée pour visualiser et ajuster l'ordre des arrêts.
            </p>
          )}
        </div>
      </section>
    </>
  );
}

