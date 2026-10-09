"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import dynamic from "next/dynamic";
import ForbiddenError from "@/components/ForbiddenError";

const LocationPickerMap = dynamic(() => import("@/components/LocationPickerMap"), { ssr: false });

type Incident = {
  id: string;
  incident_type: string;
  severity: string;
  description: string;
  photo_media_token?: string | null;
  is_resolved: boolean;
  created_at: string;
};

type Shift = {
  id: string;
  vehicle_id: string;
  status: string;
  started_at: string;
};

type Cylinder = {
  id: string;
  gas_type: string;
  size_kg: number;
};

export default function SafetyPage() {
  const [rows, setRows] = useState<Incident[]>([]);
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [cylinders, setCylinders] = useState<Cylinder[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const { t, te } = useI18n();

  // Create Incident Modal State
  const [showCreate, setShowCreate] = useState(false);
  const [shiftId, setShiftId] = useState("");
  const [incidentType, setIncidentType] = useState("GAS_LEAK");
  const [severity, setSeverity] = useState("HIGH");
  const [cylinderTypeId, setCylinderTypeId] = useState("");
  const [description, setDescription] = useState("");
  const [latitude, setLatitude] = useState("33.5731");
  const [longitude, setLongitude] = useState("-7.5898");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [filterSeverity, setFilterSeverity] = useState<string>("ALL");

  async function loadData() {
    try {
      const [incidents, sList, cList] = await Promise.all([
        api<Incident[]>("/api/v1/safety-incidents"),
        api<Shift[]>("/api/v1/shifts").catch(() => []),
        api<Cylinder[]>("/api/v1/cylinder-types").catch(() => []),
      ]);
      setRows(incidents);
      setShifts(sList);
      setCylinders(cList);
      if (sList.length > 0 && !shiftId) {
        setShiftId(sList[0].id);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  async function resolve(id: string) {
    try {
      await api(`/api/v1/safety-incidents/${id}/resolve`, { method: "POST" });
      setSuccess("Incident résolu et archivé avec succès.");
      setTimeout(() => setSuccess(""), 4000);
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  async function handleCreateIncident(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      if (!shiftId) {
        throw new Error("Veuillez sélectionner un shift associé à cet incident.");
      }

      await api("/api/v1/safety-incidents", {
        method: "POST",
        body: JSON.stringify({
          shift_id: shiftId,
          incident_type: incidentType,
          severity,
          cylinder_type_id: cylinderTypeId || undefined,
          description: description.trim(),
          latitude: latitude ? parseFloat(latitude) : undefined,
          longitude: longitude ? parseFloat(longitude) : undefined,
        }),
      });

      setSuccess("Incident de sécurité déclaré et consigné au registre ADR !");
      setShowCreate(false);
      setDescription("");
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  const filteredRows = rows.filter((r) => {
    if (filterSeverity === "ALL") return true;
    return r.severity === filterSeverity;
  });

  const openIncidents = rows.filter((r) => !r.is_resolved);
  const criticalIncidents = rows.filter((r) => !r.is_resolved && r.severity === "CRITICAL");
  if (error && error.toLowerCase().includes("not permitted")) {
    return <ForbiddenError error={error} />;
  }

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>🛡️</span>
            <span>{t("safetyTitle")}</span>
          </h1>
          <p className="page-sub">{t("safetySub")}</p>
        </div>
        <button
          type="button"
          className="btn danger"
          onClick={() => setShowCreate(true)}
        >
          <span>🚨</span>
          <span>Déclarer un Incident ADR</span>
        </button>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}
      {success && <div className="alert-banner success">✓ {success}</div>}

      {/* ADR Safety Focal Diagnostic Deck */}
      <section className="editorial-grid-hero">
        <div className="focal-hero-block" style={{ borderLeftColor: criticalIncidents.length > 0 ? "var(--signal-danger)" : "var(--signal-ok)" }}>
          <div className="focal-hero-meta">
            <span className="kpi-label">
              <span>⚠️</span> Conformité Réglementaire ADR & Gaz
            </span>
            <span className={`badge ${criticalIncidents.length > 0 ? "danger" : "ok"}`}>
              {criticalIncidents.length > 0 ? "ALERTE ACTIVE" : "STATUT NOMINAL"}
            </span>
          </div>
          <div className="focal-hero-value" style={{ color: criticalIncidents.length > 0 ? "var(--signal-danger)" : "var(--ink-primary)" }}>
            {criticalIncidents.length} <span style={{ fontSize: "1.2rem", color: "var(--ink-muted)", fontWeight: 500 }}>critiques non résolus</span>
          </div>
          <p className="page-sub" style={{ marginTop: "var(--space-8)" }}>
            Protocole d'isolement et de quarantaine pour fuites, anomalies de robinets ou collisions de flotte.
          </p>
        </div>

        <div className="kpi-deck">
          <div className={`kpi-card ${openIncidents.length > 0 ? "alert-warn" : ""}`}>
            <div className="kpi-label">
              <span>📋</span> Incidents Ouverts
            </div>
            <div className="kpi-val" style={{ color: openIncidents.length > 0 ? "var(--signal-warn)" : "var(--signal-ok)" }}>
              {openIncidents.length} / {rows.length}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>En cours d'investigation</small>
          </div>

          <div className="kpi-card" style={{ borderLeft: "3px solid var(--signal-ok)" }}>
            <div className="kpi-label">
              <span>✓</span> Incidents Clôturés
            </div>
            <div className="kpi-val" style={{ color: "var(--signal-ok)" }}>
              {rows.filter((r) => r.is_resolved).length}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>Archivés avec attestation</small>
          </div>
        </div>
      </section>

      {/* Modal Déclaration Incident */}
      {showCreate && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content">
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🚨</span> Consigner un Incident de Sécurité ADR
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowCreate(false)}>✕</button>
            </div>

            <form onSubmit={handleCreateIncident}>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-12)" }}>
                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Shift Chauffeur / Véhicule concerné *</label>
                  <select
                    className="input"
                    value={shiftId}
                    onChange={(e) => setShiftId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un shift --</option>
                    {shifts.map((s) => (
                      <option key={s.id} value={s.id}>
                        Shift {s.id.slice(0, 8)} ({s.status}) · {new Date(s.started_at).toLocaleDateString()}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">Type d'incident *</label>
                  <select
                    className="input"
                    value={incidentType}
                    onChange={(e) => setIncidentType(e.target.value)}
                    required
                  >
                    <option value="GAS_LEAK">Fuite de gaz (Gas Leak)</option>
                    <option value="CYLINDER_DEFECT">Bouteille défectueuse / Fissure</option>
                    <option value="EQUIPMENT_FAILURE">Défaillance équipement / Camion</option>
                    <option value="TRAFFIC_ACCIDENT">Accident de la circulation</option>
                    <option value="SECURITY_BREACH">Infraction de sécurité / Vol</option>
                    <option value="OTHER">Autre incident</option>
                  </select>
                </div>

                <div>
                  <label className="form-label">Niveau de sévérité *</label>
                  <select
                    className="input"
                    value={severity}
                    onChange={(e) => setSeverity(e.target.value)}
                    required
                  >
                    <option value="LOW">Faible (LOW)</option>
                    <option value="HIGH">Élevée (HIGH)</option>
                    <option value="CRITICAL">Critique / Arrêt Immédiat (CRITICAL)</option>
                  </select>
                </div>

                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Calibre de bouteille impliqué (le cas échéant)</label>
                  <select
                    className="input"
                    value={cylinderTypeId}
                    onChange={(e) => setCylinderTypeId(e.target.value)}
                  >
                    <option value="">-- Aucun ou Non Spécifié --</option>
                    {cylinders.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.size_kg} kg — {c.gas_type}
                      </option>
                    ))}
                  </select>
                </div>

                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Localisation GPS (Cliquer sur la carte pour choisir)</label>
                  <LocationPickerMap
                    latitude={parseFloat(latitude) || 33.5731}
                    longitude={parseFloat(longitude) || -7.5898}
                    onLocationChange={(lat, lng) => {
                      setLatitude(lat.toFixed(6));
                      setLongitude(lng.toFixed(6));
                    }}
                  />
                  <div style={{ display: "flex", gap: "var(--space-8)", marginTop: "var(--space-8)" }}>
                    <input
                      type="number"
                      step="any"
                      className="input"
                      placeholder="Latitude"
                      value={latitude}
                      onChange={(e) => setLatitude(e.target.value)}
                      style={{ flex: 1 }}
                    />
                    <input
                      type="number"
                      step="any"
                      className="input"
                      placeholder="Longitude"
                      value={longitude}
                      onChange={(e) => setLongitude(e.target.value)}
                      style={{ flex: 1 }}
                    />
                  </div>
                </div>

                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Description détaillée des faits *</label>
                  <textarea
                    className="input"
                    rows={4}
                    placeholder="Préciser l'état du robinet, l'odeur suspecte, la localisation exacte et les mesures d'isolement prises..."
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowCreate(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn danger" disabled={isSubmitting}>
                  {isSubmitting ? "Consignation..." : "🚨 Consigner l'Incident"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Incidents Table */}
      <div className="panel">
        <div className="panel-header">
          <h2 className="panel-title">
            <span>📋</span> Registre ADR des Incidents ({filteredRows.length})
          </h2>
          <div className="row">
            <span className="muted" style={{ fontSize: "0.8rem" }}>Sévérité :</span>
            <select
              className="input"
              style={{ width: "auto", fontSize: "0.85rem" }}
              value={filterSeverity}
              onChange={(e) => setFilterSeverity(e.target.value)}
            >
              <option value="ALL">Toutes</option>
              <option value="CRITICAL">Critiques uniquement</option>
              <option value="HIGH">Élevées</option>
              <option value="LOW">Faibles</option>
            </select>
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t("when")}</th>
                <th>{t("type")}</th>
                <th>{t("severity")}</th>
                <th>{t("description")}</th>
                <th>Preuve</th>
                <th>{t("status")}</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredRows.map((r) => (
                <tr key={r.id}>
                  <td><code className="mono">{String(r.created_at).slice(0, 19).replace("T", " ")}</code></td>
                  <td style={{ fontWeight: 600 }}>{te(r.incident_type)}</td>
                  <td>
                    <span
                      className={`badge ${
                        r.severity === "CRITICAL"
                          ? "danger"
                          : r.severity === "HIGH"
                            ? "warn"
                            : "info"
                      }`}
                    >
                      <span>
                        {r.severity === "CRITICAL" ? "▲ " : "● "}
                        {te(r.severity)}
                      </span>
                    </span>
                  </td>
                  <td style={{ maxWidth: 320 }} className="prose-limit">{r.description}</td>
                  <td>
                    {r.photo_media_token ? (
                      <span className="badge neutral">
                        📷 Capturée
                      </span>
                    ) : (
                      <span className="muted">—</span>
                    )}
                  </td>
                  <td>
                    <span className={`badge ${r.is_resolved ? "ok" : "warn"}`}>
                      {r.is_resolved ? "● " + t("RESOLVED") : "▲ " + t("OPEN")}
                    </span>
                  </td>
                  <td>
                    {!r.is_resolved ? (
                      <button
                        type="button"
                        className="btn secondary sm"
                        onClick={() => resolve(r.id)}
                      >
                        {t("resolveBtn")}
                      </button>
                    ) : (
                      <span className="muted" style={{ fontSize: "0.8rem" }}>Clôturé</span>
                    )}
                  </td>
                </tr>
              ))}
              {filteredRows.length === 0 && (
                <tr>
                  <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                    {t("noIncidents")}
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

