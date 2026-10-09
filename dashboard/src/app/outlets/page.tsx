"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import ForbiddenError from "@/components/ForbiddenError";

const OutletMap = dynamic(() => import("@/components/OutletMap"), { ssr: false });
const LocationPickerMap = dynamic(() => import("@/components/LocationPickerMap"), { ssr: false });

import type { Outlet } from "@/components/types";

type Balance = { balance_mad: number; credit_limit_mad: number };

export default function OutletsPage() {
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [sel, setSel] = useState<Outlet | null>(null);
  const [bal, setBal] = useState<Balance | null>(null);
  const [search, setSearch] = useState("");
  const { t } = useI18n();

  // Create Modal State
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [contactName, setContactName] = useState("");
  const [phone, setPhone] = useState("+212");
  const [latitude, setLatitude] = useState("33.5731");
  const [longitude, setLongitude] = useState("-7.5898");
  const [geofenceRadius, setGeofenceRadius] = useState(60);
  const [creditLimit, setCreditLimit] = useState(5000);
  const [paymentTerms, setPaymentTerms] = useState(15);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Edit Modal State
  const [showEdit, setShowEdit] = useState(false);
  const [editId, setEditId] = useState("");
  const [editName, setEditName] = useState("");
  const [editContactName, setEditContactName] = useState("");
  const [editPhone, setEditPhone] = useState("");
  const [editLatitude, setEditLatitude] = useState("33.5731");
  const [editLongitude, setEditLongitude] = useState("-7.5898");
  const [editGeofenceRadius, setEditGeofenceRadius] = useState(60);
  const [editCreditLimit, setEditCreditLimit] = useState(5000);
  const [editPaymentTerms, setEditPaymentTerms] = useState(15);
  const [editIsActive, setEditIsActive] = useState(true);

  async function loadOutlets() {
    try {
      const data = await api<Outlet[]>("/api/v1/outlets");
      setOutlets(data);
      if (data.length > 0 && !sel) {
        openOutlet(data[0]);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    loadOutlets();
  }, []);

  async function openOutlet(o: Outlet) {
    setSel(o);
    setBal(null);
    try {
      const b = await api<Balance>(`/api/v1/credit/outlets/${o.id}/balance`);
      setBal(b);
    } catch {
      setBal(null);
    }
  }

  async function updateCredit(value: number) {
    if (!sel) return;
    try {
      await api(`/api/v1/outlets/${sel.id}`, {
        method: "PATCH",
        body: JSON.stringify({ credit_limit_mad: value }),
      });
      setOutlets((prev) =>
        prev.map((x) => (x.id === sel.id ? { ...x, credit_limit_mad: value } : x))
      );
      setSuccess(`Plafond de crédit mis à jour (${value} MAD)`);
      setTimeout(() => setSuccess(""), 4000);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  async function handleCreateOutlet(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      await api("/api/v1/outlets", {
        method: "POST",
        body: JSON.stringify({
          name: name.trim(),
          contact_name: contactName.trim() || undefined,
          phone: phone.trim(),
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude),
          geofence_radius_m: Number(geofenceRadius),
          credit_limit_mad: Number(creditLimit),
          payment_terms_days: Number(paymentTerms),
        }),
      });

      setSuccess(`Point de vente « ${name} » créé avec succès !`);
      setShowCreate(false);
      setName("");
      setContactName("");
      setPhone("+212");
      await loadOutlets();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  function openEditOutlet(o: Outlet) {
    setEditId(o.id);
    setEditName(o.name);
    setEditContactName(o.contact_name || "");
    setEditPhone(o.phone);
    setEditLatitude(o.latitude !== null && o.latitude !== undefined ? String(o.latitude) : "33.5731");
    setEditLongitude(o.longitude !== null && o.longitude !== undefined ? String(o.longitude) : "-7.5898");
    setEditGeofenceRadius(o.geofence_radius_m || 60);
    setEditCreditLimit(o.credit_limit_mad || 0);
    setEditPaymentTerms(o.payment_terms_days || 0);
    setEditIsActive(o.is_active);
    setShowEdit(true);
  }

  async function handleUpdateOutlet(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      await api(`/api/v1/outlets/${editId}`, {
        method: "PATCH",
        body: JSON.stringify({
          name: editName.trim(),
          contact_name: editContactName.trim() || undefined,
          phone: editPhone.trim(),
          latitude: parseFloat(editLatitude),
          longitude: parseFloat(editLongitude),
          geofence_radius_m: Number(editGeofenceRadius),
          credit_limit_mad: Number(editCreditLimit),
          payment_terms_days: Number(editPaymentTerms),
          is_active: editIsActive,
        }),
      });

      setSuccess(`Point de vente « ${editName} » mis à jour !`);
      setShowEdit(false);
      await loadOutlets();
      if (sel?.id === editId) {
        const updated = outlets.find((x) => x.id === editId);
        if (updated) setSel({ ...updated, name: editName, phone: editPhone, contact_name: editContactName });
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleDeleteOutlet(o: Outlet) {
    if (!confirm(`Confirmer la suppression du point de vente « ${o.name} » ?`)) return;
    setError("");
    setSuccess("");
    try {
      await api(`/api/v1/outlets/${o.id}`, { method: "DELETE" });
      setSuccess(`Point de vente « ${o.name} » supprimé.`);
      if (sel?.id === o.id) setSel(null);
      await loadOutlets();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  const filteredOutlets = outlets.filter((o) => {
    if (!search.trim()) return true;
    const s = search.toLowerCase();
    return (
      o.name.toLowerCase().includes(s) ||
      o.phone.toLowerCase().includes(s) ||
      (o.contact_name && o.contact_name.toLowerCase().includes(s))
    );
  });

  if (error && error.toLowerCase().includes("not permitted")) {
    return <ForbiddenError error={error} />;
  }

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>🏪</span>
            <span>{t("outletsTitle")}</span>
          </h1>
          <p className="page-sub">{t("outletsSub")}</p>
        </div>
        <button
          type="button"
          className="btn"
          onClick={() => setShowCreate(true)}
        >
          <span>＋</span>
          <span>Nouveau Point de Vente</span>
        </button>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}
      {success && <div className="alert-banner success">✓ {success}</div>}

      {/* Asymmetric Map & Inspector Grid */}
      <section className="editorial-grid-split">
        <div className="map-box">
          <OutletMap outlets={outlets} onSelect={openOutlet} />
        </div>

        {/* Selected Outlet Dossier Inspector (Focal Point) */}
        <div className="panel" style={{ borderLeft: "3px solid var(--accent)", display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
          <div>
            <div className="panel-header">
              <span className="panel-title">
                <span>📍</span> Dossier Point de Vente
              </span>
              {sel && (
                <span className={`badge ${sel.is_active ? "ok" : "warn"}`}>
                  <span>{sel.is_active ? "● ACTIF" : "▲ INACTIF"}</span>
                </span>
              )}
            </div>

            {sel ? (
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
                <div>
                  <h3 style={{ fontSize: "1.25rem", color: "var(--ink-primary)" }}>{sel.name}</h3>
                  <p className="muted" style={{ fontSize: "0.85rem" }}>
                    Contact : <strong>{sel.contact_name || "Non renseigné"}</strong> · <code className="mono">{sel.phone}</code>
                  </p>
                </div>

                <div style={{ background: "var(--bg-surface-2)", border: "1px solid var(--border-raw)", padding: "var(--space-12)" }}>
                  <div className="kpi-label">Rayon Géofencing Validé</div>
                  <div style={{ fontFamily: "var(--font-headline)", fontSize: "1.2rem", fontWeight: 700, color: "var(--signal-info)" }}>
                    {sel.geofence_radius_m} mètres
                  </div>
                  <small className="muted">Validation GPS requise pour déchargement</small>
                </div>

                <div style={{ background: "var(--bg-surface-2)", border: "1px solid var(--border-raw)", padding: "var(--space-12)" }}>
                  <div className="kpi-label">Plafond Crédit B2B (MAD)</div>
                  <div className="row" style={{ marginTop: "var(--space-4)" }}>
                    <input
                      type="number"
                      className="input"
                      style={{ maxWidth: 160, fontWeight: 700 }}
                      defaultValue={sel.credit_limit_mad}
                      onBlur={(e) => updateCredit(Number(e.target.value))}
                    />
                    <span className="muted" style={{ fontSize: "0.85rem" }}>MAD</span>
                  </div>
                </div>

                {bal && (
                  <div style={{ background: "var(--bg-surface-2)", border: "1px solid var(--border-raw)", padding: "var(--space-12)" }}>
                    <div className="kpi-label">Encours Actuel Comptabilisé</div>
                    <div style={{ fontFamily: "var(--font-headline)", fontSize: "1.2rem", fontWeight: 700, color: bal.balance_mad > sel.credit_limit_mad ? "var(--signal-danger)" : "var(--ink-primary)" }}>
                      {bal.balance_mad.toLocaleString("fr-FR")} MAD
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <p className="muted" style={{ padding: "var(--space-24)", textAlign: "center" }}>
                Sélectionnez un point de vente sur la carte ou dans le tableau ci-dessous pour inspecter son dossier.
              </p>
            )}
          </div>

          <div style={{ borderTop: "1px solid var(--border-subtle)", paddingTop: "var(--space-12)", marginTop: "var(--space-16)" }}>
            <small className="muted">ID Unique: <code className="mono">{sel?.id ? sel.id.slice(0, 12) : "—"}</code></small>
            {sel && (
              <div style={{ display: "flex", gap: "var(--space-8)", marginTop: "var(--space-12)" }}>
                <button
                  type="button"
                  className="btn secondary sm"
                  style={{ flex: 1 }}
                  onClick={() => openEditOutlet(sel)}
                >
                  ✏️ Modifier la fiche
                </button>
                <button
                  type="button"
                  className="btn danger sm"
                  onClick={() => handleDeleteOutlet(sel)}
                >
                  🗑️ Supprimer
                </button>
              </div>
            )}
          </div>
        </div>
      </section>

      {/* Modal Création Point de Vente */}
      {showCreate && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content">
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🏪</span> Créer un Point de Vente B2B
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowCreate(false)}>✕</button>
            </div>

            <form onSubmit={handleCreateOutlet}>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-12)" }}>
                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Nom de l'enseigne *</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="Ex: Épicerie Al Amal Maarif"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Contact / Gérant</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="Ex: Mustapha Cherkaoui"
                    value={contactName}
                    onChange={(e) => setContactName(e.target.value)}
                  />
                </div>

                <div>
                  <label className="form-label">Téléphone *</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="+212612345678"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    required
                  />
                </div>

                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Localisation GPS (Cliquer sur la carte pour choisir) *</label>
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
                      required
                      style={{ flex: 1 }}
                    />
                    <input
                      type="number"
                      step="any"
                      className="input"
                      placeholder="Longitude"
                      value={longitude}
                      onChange={(e) => setLongitude(e.target.value)}
                      required
                      style={{ flex: 1 }}
                    />
                  </div>
                </div>

                <div style={{ gridColumn: "span 2", display: "flex", gap: "var(--space-8)" }}>
                  <button
                    type="button"
                    className="btn secondary sm"
                    onClick={() => { setLatitude("33.5731"); setLongitude("-7.5898"); }}
                  >
                    📍 Casa Centre
                  </button>
                  <button
                    type="button"
                    className="btn secondary sm"
                    onClick={() => { setLatitude("33.5822"); setLongitude("-7.6321"); }}
                  >
                    📍 Maarif
                  </button>
                  <button
                    type="button"
                    className="btn secondary sm"
                    onClick={() => { setLatitude("33.5333"); setLongitude("-7.6500"); }}
                  >
                    📍 Ain Chock
                  </button>
                </div>

                <div>
                  <label className="form-label">Rayon Géofencing (30-200m)</label>
                  <input
                    type="number"
                    min={30}
                    max={200}
                    className="input"
                    value={geofenceRadius}
                    onChange={(e) => setGeofenceRadius(Number(e.target.value))}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Plafond Crédit (MAD)</label>
                  <input
                    type="number"
                    min={0}
                    className="input"
                    value={creditLimit}
                    onChange={(e) => setCreditLimit(Number(e.target.value))}
                    required
                  />
                </div>

                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Délai Paiement (Jours)</label>
                  <input
                    type="number"
                    min={0}
                    className="input"
                    value={paymentTerms}
                    onChange={(e) => setPaymentTerms(Number(e.target.value))}
                    required
                  />
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowCreate(false)}>Annuler</button>
                <button type="submit" className="btn" disabled={isSubmitting}>
                  {isSubmitting ? "Création en cours..." : "✓ Enregistrer le Point de Vente"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Modification Point de Vente */}
      {showEdit && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content">
            <div className="panel-header">
              <h2 className="panel-title">
                <span>✏️</span> Modifier le Point de Vente
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowEdit(false)}>✕</button>
            </div>

            <form onSubmit={handleUpdateOutlet}>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-12)" }}>
                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Nom de l'enseigne *</label>
                  <input
                    type="text"
                    className="input"
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Contact / Gérant</label>
                  <input
                    type="text"
                    className="input"
                    value={editContactName}
                    onChange={(e) => setEditContactName(e.target.value)}
                  />
                </div>

                <div>
                  <label className="form-label">Téléphone *</label>
                  <input
                    type="text"
                    className="input"
                    value={editPhone}
                    onChange={(e) => setEditPhone(e.target.value)}
                    required
                  />
                </div>

                <div style={{ gridColumn: "span 2" }}>
                  <label className="form-label">Position GPS (Cliquer sur la carte pour déplacer)</label>
                  <div style={{ height: 260, marginBottom: "var(--space-8)", border: "1px solid var(--border-raw)" }}>
                    <LocationPickerMap
                      latitude={parseFloat(editLatitude) || 33.5731}
                      longitude={parseFloat(editLongitude) || -7.5898}
                      onLocationChange={(lat, lng) => {
                        setEditLatitude(lat.toFixed(6));
                        setEditLongitude(lng.toFixed(6));
                      }}
                    />
                  </div>
                  <div style={{ display: "flex", gap: "var(--space-8)" }}>
                    <input
                      type="number"
                      step="any"
                      className="input"
                      placeholder="Latitude"
                      value={editLatitude}
                      onChange={(e) => setEditLatitude(e.target.value)}
                      required
                      style={{ flex: 1 }}
                    />
                    <input
                      type="number"
                      step="any"
                      className="input"
                      placeholder="Longitude"
                      value={editLongitude}
                      onChange={(e) => setEditLongitude(e.target.value)}
                      required
                      style={{ flex: 1 }}
                    />
                  </div>
                </div>

                <div>
                  <label className="form-label">Rayon Géofence (mètres)</label>
                  <input
                    type="number"
                    min={30}
                    max={200}
                    className="input"
                    value={editGeofenceRadius}
                    onChange={(e) => setEditGeofenceRadius(Number(e.target.value))}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Plafond Crédit (MAD)</label>
                  <input
                    type="number"
                    min={0}
                    className="input"
                    value={editCreditLimit}
                    onChange={(e) => setEditCreditLimit(Number(e.target.value))}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Délai Paiement (Jours)</label>
                  <input
                    type="number"
                    min={0}
                    className="input"
                    value={editPaymentTerms}
                    onChange={(e) => setEditPaymentTerms(Number(e.target.value))}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Statut Opérationnel</label>
                  <select
                    className="input"
                    value={editIsActive ? "active" : "inactive"}
                    onChange={(e) => setEditIsActive(e.target.value === "active")}
                  >
                    <option value="active">● Actif</option>
                    <option value="inactive">▲ Inactif / Suspendu</option>
                  </select>
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowEdit(false)}>Annuler</button>
                <button type="submit" className="btn" disabled={isSubmitting}>
                  {isSubmitting ? "Enregistrement..." : "✓ Mettre à jour"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Tableau et Recherche */}
      <div className="panel">
        <div className="panel-header">
          <h2 className="panel-title">
            <span>📋</span> Répertoire des Points de Vente ({filteredOutlets.length})
          </h2>
          <input
            type="text"
            className="input"
            style={{ maxWidth: 280 }}
            placeholder="🔍 Filtrer par nom, téléphone..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t("name")}</th>
                <th>Contact</th>
                <th>{t("phoneCol")}</th>
                <th>{t("geofence")}</th>
                <th>{t("creditLimit")}</th>
                <th>Statut</th>
                <th style={{ textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredOutlets.map((o) => (
                <tr key={o.id} className={sel?.id === o.id ? "selected-row" : ""}>
                  <td style={{ fontWeight: 700, color: "var(--ink-primary)" }}>{o.name}</td>
                  <td>{o.contact_name || "—"}</td>
                  <td><code className="mono">{o.phone}</code></td>
                  <td>{o.geofence_radius_m} m</td>
                  <td>{o.credit_limit_mad.toLocaleString("fr-FR")} MAD</td>
                  <td>
                    <span className={`badge ${o.is_active ? "ok" : "warn"}`}>
                      {o.is_active ? "● Actif" : "▲ Inactif"}
                    </span>
                  </td>
                  <td style={{ textAlign: "right" }}>
                    <div className="row" style={{ justifyContent: "flex-end" }}>
                      <button
                        type="button"
                        className="btn secondary sm"
                        onClick={() => openOutlet(o)}
                      >
                        {sel?.id === o.id ? "Inspecté" : t("select")}
                      </button>
                      <button
                        type="button"
                        className="btn secondary sm"
                        onClick={() => openEditOutlet(o)}
                      >
                        ✏️
                      </button>
                      <button
                        type="button"
                        className="btn danger sm"
                        onClick={() => handleDeleteOutlet(o)}
                      >
                        🗑️
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {filteredOutlets.length === 0 && (
                <tr>
                  <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "var(--space-32)" }}>
                    Aucun point de vente trouvé.
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

