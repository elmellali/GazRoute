"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";

type Loc = { id: string; name: string; type: string };
type Bal = {
  location_id: string;
  cylinder_type_id: string;
  cylinder_state: string;
  quantity: number;
};
type Movement = {
  id: string;
  cylinder_state: string;
  quantity: number;
  source_type: string;
  occurred_at: string;
  from_location_id?: string;
  to_location_id?: string;
};
type Cylinder = { id: string; gas_type: string; size_kg: number };
type Vehicle = { id: string; plate_number: string; model: string; max_payload_kg: number };
type Shift = { id: string; vehicle_id: string; status: string; started_at: string };
type LoadSheet = {
  id: string;
  vehicle_id: string;
  depot_location_id: string;
  status: string;
  shift_id?: string | null;
};

export default function StockPage() {
  const [locs, setLocs] = useState<Loc[]>([]);
  const [bals, setBals] = useState<Bal[]>([]);
  const [movs, setMovs] = useState<Movement[]>([]);
  const [types, setTypes] = useState<Cylinder[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [loadSheets, setLoadSheets] = useState<LoadSheet[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const { t, te } = useI18n();

  // Load Sheet Modal State
  const [showLoadModal, setShowLoadModal] = useState(false);
  const [selectedVehicleId, setSelectedVehicleId] = useState("");
  const [selectedDepotId, setSelectedDepotId] = useState("");
  const [selectedShiftId, setSelectedShiftId] = useState("");
  const [quantities, setQuantities] = useState<Record<string, number>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function loadData() {
    try {
      const [l, b, m, c, v, s, ls] = await Promise.all([
        api<Loc[]>("/api/v1/inventory/locations"),
        api<Bal[]>("/api/v1/inventory/balances"),
        api<Movement[]>("/api/v1/inventory/movements"),
        api<Cylinder[]>("/api/v1/cylinder-types"),
        api<Vehicle[]>("/api/v1/vehicles").catch(() => []),
        api<Shift[]>("/api/v1/shifts").catch(() => []),
        api<LoadSheet[]>("/api/v1/shifts/load-sheets").catch(() => []),
      ]);
      setLocs(l);
      setBals(b);
      setMovs(m);
      setTypes(c);
      setVehicles(v);
      setShifts(s);
      setLoadSheets(ls);

      const firstDepot = l.find((x) => x.type === "depot");
      if (firstDepot) setSelectedDepotId(firstDepot.id);
      if (v.length > 0) setSelectedVehicleId(v[0].id);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  function locName(id?: string) {
    if (!id) return "—";
    return locs.find((l) => l.id === id)?.name || id.slice(0, 8);
  }

  function ctLabel(id: string) {
    const c = types.find((t) => t.id === id);
    return c ? `${c.size_kg}kg ${c.gas_type}` : id.slice(0, 8);
  }

  function vehiclePlate(id: string) {
    const v = vehicles.find((x) => x.id === id);
    return v ? `${v.plate_number} (${v.model})` : id.slice(0, 8);
  }

  async function handleCreateLoadSheet(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      const lines = Object.entries(quantities)
        .filter(([, qty]) => qty > 0)
        .map(([cylinder_type_id, quantity]) => ({
          cylinder_type_id,
          quantity: Number(quantity),
        }));

      if (lines.length === 0) {
        throw new Error("Veuillez indiquer au moins une quantité de bouteilles.");
      }

      await api("/api/v1/shifts/load-sheets", {
        method: "POST",
        body: JSON.stringify({
          vehicle_id: selectedVehicleId,
          depot_location_id: selectedDepotId,
          shift_id: selectedShiftId || undefined,
          lines,
        }),
      });

      setSuccess("Feuille de chargement émise avec succès ! En attente de validation chauffeur.");
      setShowLoadModal(false);
      setQuantities({});
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  const totalFullCylinders = bals
    .filter((b) => b.cylinder_state === "full")
    .reduce((sum, b) => sum + b.quantity, 0);

  const totalEmptyCylinders = bals
    .filter((b) => b.cylinder_state === "empty")
    .reduce((sum, b) => sum + b.quantity, 0);

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>📦</span>
            <span>{t("stockTitle")}</span>
          </h1>
          <p className="page-sub">{t("stockSub")}</p>
        </div>
        <button
          type="button"
          className="btn"
          onClick={() => setShowLoadModal(true)}
        >
          <span>＋</span>
          <span>Émettre Feuille de Chargement</span>
        </button>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}
      {success && <div className="alert-banner success">✓ {success}</div>}

      {/* Industrial Focal Inventory Balance Overview */}
      <section className="editorial-grid-hero">
        <div className="focal-hero-block">
          <div className="focal-hero-meta">
            <span className="kpi-label">
              <span>🏭</span> Disponibilité Globale Consignée
            </span>
            <span className="badge ok">IMMUTABLE LEDGER</span>
          </div>
          <div className="focal-hero-value">
            {totalFullCylinders} <span style={{ fontSize: "1.2rem", color: "var(--ink-muted)", fontWeight: 500 }}>bouteilles pleines</span>
          </div>
          <p className="page-sub" style={{ marginTop: "var(--space-8)" }}>
            Réparties sur {locs.length} emplacements (dépôts de conditionnement et camions de livraison).
          </p>
        </div>

        <div className="kpi-deck">
          <div className="kpi-card" style={{ borderLeft: "3px solid var(--signal-info)" }}>
            <div className="kpi-label">
              <span>🔄</span> Retours Vides
            </div>
            <div className="kpi-val" style={{ color: "var(--signal-info)" }}>
              {totalEmptyCylinders}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>Prêtes pour réapprovisionnement</small>
          </div>

          <div className="kpi-card" style={{ borderLeft: "3px solid var(--accent)" }}>
            <div className="kpi-label">
              <span>📋</span> Feuilles Chargement
            </div>
            <div className="kpi-val">
              {loadSheets.length}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>Bons d'armement émis</small>
          </div>
        </div>
      </section>

      {/* Modal Création Feuille de Chargement */}
      {showLoadModal && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content">
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🚛</span> Émettre une Feuille de Chargement Camion
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowLoadModal(false)}>✕</button>
            </div>

            <form onSubmit={handleCreateLoadSheet}>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-12)" }}>
                <div>
                  <label className="form-label">Camion Cible *</label>
                  <select
                    className="input"
                    value={selectedVehicleId}
                    onChange={(e) => setSelectedVehicleId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un véhicule --</option>
                    {vehicles.map((v) => (
                      <option key={v.id} value={v.id}>
                        {v.plate_number} · {v.model} (Max: {v.max_payload_kg} kg)
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">Dépôt Source *</label>
                  <select
                    className="input"
                    value={selectedDepotId}
                    onChange={(e) => setSelectedDepotId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un dépôt --</option>
                    {locs
                      .filter((l) => l.type === "depot")
                      .map((l) => (
                        <option key={l.id} value={l.id}>
                          {l.name}
                        </option>
                      ))}
                  </select>
                </div>

                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Shift Chauffeur (Optionnel)</label>
                  <select
                    className="input"
                    value={selectedShiftId}
                    onChange={(e) => setSelectedShiftId(e.target.value)}
                  >
                    <option value="">-- Aucun / À associer ultérieurement --</option>
                    {shifts.map((s) => (
                      <option key={s.id} value={s.id}>
                        Shift {s.id.slice(0, 8)} ({s.status}) · {new Date(s.started_at).toLocaleDateString()}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div style={{ marginTop: "var(--space-16)" }}>
                <label className="form-label" style={{ marginBottom: "var(--space-8)" }}>
                  Quantités de bouteilles pleines à charger
                </label>
                <div style={{ background: "var(--bg-surface-2)", padding: "var(--space-12)", border: "1px solid var(--border-raw)" }}>
                  {types.map((t) => (
                    <div
                      key={t.id}
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        padding: "var(--space-8) 0",
                        borderBottom: "1px solid var(--border-subtle)",
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 600, color: "var(--ink-primary)" }}>{t.size_kg} kg — {t.gas_type}</div>
                        <small className="muted">Bouteille consignée standard</small>
                      </div>
                      <div className="row">
                        <input
                          type="number"
                          min={0}
                          className="input"
                          style={{ width: 100, textAlign: "center", fontWeight: 700 }}
                          placeholder="0"
                          value={quantities[t.id] ?? ""}
                          onChange={(e) =>
                            setQuantities({ ...quantities, [t.id]: Math.max(0, parseInt(e.target.value) || 0) })
                          }
                        />
                        <span className="muted" style={{ fontSize: "0.85rem" }}>unités</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowLoadModal(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn" disabled={isSubmitting}>
                  {isSubmitting ? "Émission..." : "✓ Valider & Émettre le Chargement"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Asymmetric Split: Soldes par Emplacement (Left) & Feuilles de Chargement (Right) */}
      <section className="editorial-grid-split">
        {/* Balances Ledger */}
        <div className="panel">
          <div className="panel-header">
            <h2 className="panel-title">
              <span>📍</span> {t("balancesByLocation")}
            </h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{t("location")}</th>
                  <th>{t("cylinder")}</th>
                  <th>{t("state")}</th>
                  <th>{t("qty")}</th>
                </tr>
              </thead>
              <tbody>
                {bals.map((b, i) => (
                  <tr key={i}>
                    <td style={{ fontWeight: 700, color: "var(--ink-primary)" }}>{locName(b.location_id)}</td>
                    <td>{ctLabel(b.cylinder_type_id)}</td>
                    <td>
                      <span
                        className={`badge ${
                          b.cylinder_state === "full"
                            ? "ok"
                            : b.cylinder_state === "defective"
                              ? "danger"
                              : "info"
                        }`}
                      >
                        {te(b.cylinder_state)}
                      </span>
                    </td>
                    <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700, fontSize: "1rem" }}>{b.quantity}</td>
                  </tr>
                ))}
                {bals.length === 0 && (
                  <tr>
                    <td colSpan={4} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                      {t("noBalances")}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Load Sheets Register */}
        <div className="panel" style={{ borderLeft: "3px solid var(--accent)" }}>
          <div className="panel-header">
            <h2 className="panel-title">
              <span>📋</span> Feuilles de Chargement ({loadSheets.length})
            </h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Véhicule</th>
                  <th>Statut</th>
                </tr>
              </thead>
              <tbody>
                {loadSheets.slice(0, 10).map((ls) => (
                  <tr key={ls.id}>
                    <td><code className="mono">{ls.id.slice(0, 8)}</code></td>
                    <td style={{ fontWeight: 600 }}>{vehiclePlate(ls.vehicle_id)}</td>
                    <td>
                      <span
                        className={`badge ${
                          ls.status === "ACCEPTED"
                            ? "ok"
                            : ls.status === "PENDING_ACCEPT"
                              ? "warn"
                              : "info"
                        }`}
                      >
                        {ls.status === "PENDING_ACCEPT" ? "⏳ Chauffeur" : ls.status}
                      </span>
                    </td>
                  </tr>
                ))}
                {loadSheets.length === 0 && (
                  <tr>
                    <td colSpan={3} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                      Aucune feuille enregistrée.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Mouvements Récents Immuables */}
      <div className="panel">
        <div className="panel-header">
          <h2 className="panel-title">
            <span>⏱️</span> {t("recentMovements")}
          </h2>
          <span className="badge neutral">JOURNAL D'AUDIT IMMUABLE</span>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t("when")}</th>
                <th>{t("type")}</th>
                <th>{t("state")}</th>
                <th>{t("qty")}</th>
                <th>{t("fromTo")}</th>
              </tr>
            </thead>
            <tbody>
              {movs.slice(0, 30).map((m) => (
                <tr key={m.id}>
                  <td><code className="mono">{String(m.occurred_at).slice(0, 19).replace("T", " ")}</code></td>
                  <td style={{ fontWeight: 600 }}>{te(m.source_type)}</td>
                  <td>
                    <span
                      className={`badge ${
                        m.cylinder_state === "full"
                          ? "ok"
                          : m.cylinder_state === "defective"
                            ? "danger"
                            : "info"
                      }`}
                    >
                      {te(m.cylinder_state)}
                    </span>
                  </td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>{m.quantity}</td>
                  <td>
                    {locName(m.from_location_id)} → {locName(m.to_location_id)}
                  </td>
                </tr>
              ))}
              {movs.length === 0 && (
                <tr>
                  <td colSpan={5} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                    Aucun mouvement de stock consigné.
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

