"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";

const OutletMap = dynamic(() => import("@/components/OutletMap"), { ssr: false });

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

  const filteredOutlets = outlets.filter((o) => {
    if (!search.trim()) return true;
    const s = search.toLowerCase();
    return (
      o.name.toLowerCase().includes(s) ||
      o.phone.toLowerCase().includes(s) ||
      (o.contact_name && o.contact_name.toLowerCase().includes(s))
    );
  });

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

                <div>
                  <label className="form-label">Latitude GPS *</label>
                  <input
                    type="number"
                    step="any"
                    className="input"
                    placeholder="33.5731"
                    value={latitude}
                    onChange={(e) => setLatitude(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Longitude GPS *</label>
                  <input
                    type="number"
                    step="any"
                    className="input"
                    placeholder="-7.5898"
                    value={longitude}
                    onChange={(e) => setLongitude(e.target.value)}
                    required
                  />
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
                <th>Action</th>
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
                  <td>
                    <button
                      type="button"
                      className="btn secondary sm"
                      onClick={() => openOutlet(o)}
                    >
                      {sel?.id === o.id ? "Inspecté" : t("select")}
                    </button>
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

