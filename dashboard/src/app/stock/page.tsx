"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import ForbiddenError from "@/components/ForbiddenError";

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
type Cylinder = { id: string; gas_type: string; size_kg: number; deposit_amount_mad?: number; base_sale_price_mad?: number };
type Vehicle = { id: string; plate_number: string; model: string; max_payload_kg: number; is_active?: boolean };
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

  // Active Tab
  const [activeTab, setActiveTab] = useState<"inventory" | "vehicles" | "depots" | "catalog">("inventory");

  // Load Sheet Modal State
  const [showLoadModal, setShowLoadModal] = useState(false);
  const [selectedVehicleId, setSelectedVehicleId] = useState("");
  const [selectedDepotId, setSelectedDepotId] = useState("");
  const [selectedShiftId, setSelectedShiftId] = useState("");
  const [quantities, setQuantities] = useState<Record<string, number>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Vehicle Modal State
  const [showVehicleModal, setShowVehicleModal] = useState(false);
  const [editingVehicle, setEditingVehicle] = useState<Vehicle | null>(null);
  const [vehiclePlate, setVehiclePlate] = useState("");
  const [vehicleModel, setVehicleModel] = useState("");
  const [vehiclePayload, setVehiclePayload] = useState(3500);

  // Depot Modal State
  const [showDepotModal, setShowDepotModal] = useState(false);
  const [depotName, setDepotName] = useState("");

  // Factory Receipt Modal State
  const [showFactoryModal, setShowFactoryModal] = useState(false);
  const [factoryDepotId, setFactoryDepotId] = useState("");
  const [factoryQuantities, setFactoryQuantities] = useState<Record<string, number>>({});

  // Catalog Modal State
  const [showCatalogModal, setShowCatalogModal] = useState(false);
  const [editingType, setEditingType] = useState<Cylinder | null>(null);
  const [ctGasType, setCtGasType] = useState("butane");
  const [ctSize, setCtSize] = useState(12);
  const [ctDeposit, setCtDeposit] = useState(120);
  const [ctPrice, setCtPrice] = useState(40);

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
      if (firstDepot) setSelectedDepotId((prev) => prev || firstDepot.id);
      if (v.length > 0) setSelectedVehicleId((prev) => prev || v[0].id);
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

  function getVehiclePlate(id: string) {
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

  async function handleSaveVehicle(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      if (editingVehicle) {
        await api(`/api/v1/vehicles/${editingVehicle.id}`, {
          method: "PATCH",
          body: JSON.stringify({
            plate_number: vehiclePlate.trim(),
            model: vehicleModel.trim() || undefined,
            max_payload_kg: Number(vehiclePayload),
          }),
        });
        setSuccess(`Camion ${vehiclePlate} mis à jour.`);
      } else {
        const created = await api<Vehicle>("/api/v1/vehicles", {
          method: "POST",
          body: JSON.stringify({
            plate_number: vehiclePlate.trim(),
            model: vehicleModel.trim() || undefined,
            max_payload_kg: Number(vehiclePayload),
          }),
        });
        setSuccess(`Camion ${created.plate_number} ajouté à la flotte avec succès.`);
        setSelectedVehicleId(created.id);
      }
      setShowVehicleModal(false);
      setEditingVehicle(null);
      setVehiclePlate("");
      setVehicleModel("");
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleDeleteVehicle(v: Vehicle) {
    if (!confirm(`Confirmer la suppression du camion ${v.plate_number} ?`)) return;
    setError("");
    setSuccess("");
    try {
      await api(`/api/v1/vehicles/${v.id}`, { method: "DELETE" });
      setSuccess(`Camion ${v.plate_number} supprimé.`);
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  async function handleSaveDepot(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      const created = await api<Loc>("/api/v1/inventory/locations", {
        method: "POST",
        body: JSON.stringify({
          name: depotName.trim(),
          type: "depot",
        }),
      });
      setSuccess(`Dépôt "${created.name}" créé avec succès.`);
      setSelectedDepotId(created.id);
      setShowDepotModal(false);
      setDepotName("");
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleDeleteDepot(l: Loc) {
    if (!confirm(`Confirmer la suppression du dépôt "${l.name}" ?`)) return;
    setError("");
    setSuccess("");
    try {
      await api(`/api/v1/inventory/locations/${l.id}`, { method: "DELETE" });
      setSuccess(`Dépôt "${l.name}" supprimé.`);
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  async function handleFactoryReceipt(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      const lines = Object.entries(factoryQuantities)
        .filter(([, qty]) => qty > 0)
        .map(([cylinder_type_id, quantity]) => ({
          cylinder_type_id,
          quantity: Number(quantity),
        }));

      if (lines.length === 0) {
        throw new Error("Veuillez indiquer au moins une quantité reçue de bouteilles pleines.");
      }

      await api("/api/v1/inventory/factory-receipt", {
        method: "POST",
        body: JSON.stringify({
          depot_location_id: factoryDepotId || selectedDepotId,
          lines,
        }),
      });

      setSuccess("Entrée de stock usine enregistrée ! Le solde du dépôt a été actualisé.");
      setShowFactoryModal(false);
      setFactoryQuantities({});
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleSaveCatalog(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      if (editingType) {
        await api(`/api/v1/cylinder-types/${editingType.id}`, {
          method: "PATCH",
          body: JSON.stringify({
            gas_type: ctGasType,
            size_kg: Number(ctSize),
            deposit_amount_mad: Number(ctDeposit),
            base_sale_price_mad: Number(ctPrice),
          }),
        });
        setSuccess(`Format ${ctSize}kg mis à jour.`);
      } else {
        await api("/api/v1/cylinder-types", {
          method: "POST",
          body: JSON.stringify({
            gas_type: ctGasType,
            size_kg: Number(ctSize),
            deposit_amount_mad: Number(ctDeposit),
            base_sale_price_mad: Number(ctPrice),
          }),
        });
        setSuccess(`Format ${ctSize}kg ajouté au catalogue.`);
      }
      setShowCatalogModal(false);
      setEditingType(null);
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleDeleteCatalog(c: Cylinder) {
    if (!confirm(`Confirmer la suppression du format ${c.size_kg}kg ?`)) return;
    setError("");
    setSuccess("");
    try {
      await api(`/api/v1/cylinder-types/${c.id}`, { method: "DELETE" });
      setSuccess(`Format ${c.size_kg}kg supprimé.`);
      await loadData();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  const depotsList = locs.filter((l) => l.type === "depot");

  const totalFullCylinders = bals
    .filter((b) => b.cylinder_state === "full")
    .reduce((sum, b) => sum + b.quantity, 0);

  const totalEmptyCylinders = bals
    .filter((b) => b.cylinder_state === "empty")
    .reduce((sum, b) => sum + b.quantity, 0);

  if (error && error.toLowerCase().includes("not permitted")) {
    return <ForbiddenError error={error} />;
  }

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
        <div className="row">
          <button
            type="button"
            className="btn secondary sm"
            onClick={() => {
              setEditingVehicle(null);
              setVehiclePlate("");
              setVehicleModel("");
              setVehiclePayload(3500);
              setShowVehicleModal(true);
            }}
          >
            <span>＋</span>
            <span>Nouveau Camion</span>
          </button>
          <button
            type="button"
            className="btn secondary sm"
            onClick={() => {
              setDepotName("");
              setShowDepotModal(true);
            }}
          >
            <span>＋</span>
            <span>Nouveau Dépôt</span>
          </button>
          <button
            type="button"
            className="btn secondary sm"
            onClick={() => {
              setFactoryDepotId(selectedDepotId || (depotsList[0]?.id ?? ""));
              setShowFactoryModal(true);
            }}
          >
            <span>🏭</span>
            <span>Entrée Stock Usine</span>
          </button>
          <button
            type="button"
            className="btn sm"
            onClick={() => setShowLoadModal(true)}
          >
            <span>＋</span>
            <span>Émettre Feuille de Chargement</span>
          </button>
        </div>
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
            Réparties sur {locs.length} emplacements ({depotsList.length} dépôts et {vehicles.length} camions de livraison).
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

      {/* Navigation Pills */}
      <div style={{ display: "flex", gap: "var(--space-8)", marginBottom: "var(--space-16)", borderBottom: "1px solid var(--border-raw)", paddingBottom: "var(--space-8)" }}>
        <button
          type="button"
          className={`btn ${activeTab === "inventory" ? "" : "secondary"} sm`}
          onClick={() => setActiveTab("inventory")}
        >
          <span>📦 Inventaire & Mouvements</span>
        </button>
        <button
          type="button"
          className={`btn ${activeTab === "vehicles" ? "" : "secondary"} sm`}
          onClick={() => setActiveTab("vehicles")}
        >
          <span>🚛 Flotte de Camions ({vehicles.length})</span>
        </button>
        <button
          type="button"
          className={`btn ${activeTab === "depots" ? "" : "secondary"} sm`}
          onClick={() => setActiveTab("depots")}
        >
          <span>🏭 Dépôts Sources ({depotsList.length})</span>
        </button>
        <button
          type="button"
          className={`btn ${activeTab === "catalog" ? "" : "secondary"} sm`}
          onClick={() => setActiveTab("catalog")}
        >
          <span>🏷️ Types & Tarifs ({types.length})</span>
        </button>
      </div>

      {/* Tab: Flotte de Camions */}
      {activeTab === "vehicles" && (
        <div className="panel" style={{ marginBottom: "var(--space-20)" }}>
          <div className="panel-header">
            <h2 className="panel-title">
              <span>🚛</span> Gestion de la Flotte de Camions ({vehicles.length})
            </h2>
            <button
              type="button"
              className="btn sm"
              onClick={() => {
                setEditingVehicle(null);
                setVehiclePlate("");
                setVehicleModel("");
                setVehiclePayload(3500);
                setShowVehicleModal(true);
              }}
            >
              ＋ Ajouter un Camion
            </button>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Immatriculation</th>
                  <th>Modèle</th>
                  <th>Charge Max (kg)</th>
                  <th>Statut</th>
                  <th style={{ textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {vehicles.map((v) => (
                  <tr key={v.id}>
                    <td>
                      <code className="mono" style={{ fontSize: "1rem", fontWeight: 700 }}>{v.plate_number}</code>
                    </td>
                    <td style={{ fontWeight: 600 }}>{v.model || "—"}</td>
                    <td style={{ fontFamily: "var(--font-mono)" }}>{v.max_payload_kg ? `${v.max_payload_kg} kg` : "—"}</td>
                    <td>
                      <span className="badge ok">
                        <span>● ACTIF</span>
                      </span>
                    </td>
                    <td style={{ textAlign: "right" }}>
                      <div className="row" style={{ justifyContent: "flex-end" }}>
                        <button
                          type="button"
                          className="btn secondary sm"
                          onClick={() => {
                            setEditingVehicle(v);
                            setVehiclePlate(v.plate_number);
                            setVehicleModel(v.model || "");
                            setVehiclePayload(v.max_payload_kg || 3500);
                            setShowVehicleModal(true);
                          }}
                        >
                          Modifier
                        </button>
                        <button
                          type="button"
                          className="btn danger sm"
                          onClick={() => handleDeleteVehicle(v)}
                        >
                          Supprimer
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {vehicles.length === 0 && (
                  <tr>
                    <td colSpan={5} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                      Aucun camion enregistré dans la flotte. Cliquez sur "Ajouter un Camion" pour commencer.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Tab: Dépôts Sources */}
      {activeTab === "depots" && (
        <div className="panel" style={{ marginBottom: "var(--space-20)" }}>
          <div className="panel-header">
            <h2 className="panel-title">
              <span>🏭</span> Gestion des Dépôts & Centres de Conditionnement ({depotsList.length})
            </h2>
            <button
              type="button"
              className="btn sm"
              onClick={() => {
                setDepotName("");
                setShowDepotModal(true);
              }}
            >
              ＋ Ajouter un Dépôt
            </button>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Nom du Dépôt</th>
                  <th>Type</th>
                  <th>Identifiant Interne</th>
                  <th style={{ textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {depotsList.map((d) => (
                  <tr key={d.id}>
                    <td style={{ fontWeight: 700, color: "var(--ink-primary)" }}>{d.name}</td>
                    <td>
                      <span className="badge info">
                        <span>DÉPÔT SOURCE</span>
                      </span>
                    </td>
                    <td><code className="mono">{d.id}</code></td>
                    <td style={{ textAlign: "right" }}>
                      <button
                        type="button"
                        className="btn danger sm"
                        onClick={() => handleDeleteDepot(d)}
                      >
                        Supprimer
                      </button>
                    </td>
                  </tr>
                ))}
                {depotsList.length === 0 && (
                  <tr>
                    <td colSpan={4} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                      Aucun dépôt source enregistré. Cliquez sur "Ajouter un Dépôt".
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Tab: Types de Bouteilles & Tarifs */}
      {activeTab === "catalog" && (
        <div className="panel" style={{ marginBottom: "var(--space-20)" }}>
          <div className="panel-header">
            <h2 className="panel-title">
              <span>🏷️</span> Catalogue des Formats & Tarification ({types.length})
            </h2>
            <button
              type="button"
              className="btn sm"
              onClick={() => {
                setEditingType(null);
                setCtGasType("butane");
                setCtSize(12);
                setCtDeposit(120);
                setCtPrice(40);
                setShowCatalogModal(true);
              }}
            >
              ＋ Nouveau Format
            </button>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Format (kg)</th>
                  <th>Gaz</th>
                  <th>Consigne (MAD)</th>
                  <th>Recharge (MAD)</th>
                  <th style={{ textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {types.map((t) => (
                  <tr key={t.id}>
                    <td><span style={{ fontWeight: 700, fontSize: "1.1rem" }}>{t.size_kg} kg</span></td>
                    <td>
                      <span className={`badge ${t.gas_type === "propane" ? "warn" : "info"}`}>
                        {t.gas_type.toUpperCase()}
                      </span>
                    </td>
                    <td style={{ fontFamily: "var(--font-mono)" }}>
                      {t.deposit_amount_mad != null ? `${t.deposit_amount_mad} MAD` : "—"}
                    </td>
                    <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700, color: "var(--ink-primary)" }}>
                      {t.base_sale_price_mad != null ? `${t.base_sale_price_mad} MAD` : "—"}
                    </td>
                    <td style={{ textAlign: "right" }}>
                      <div className="row" style={{ justifyContent: "flex-end" }}>
                        <button
                          type="button"
                          className="btn secondary sm"
                          onClick={() => {
                            setEditingType(t);
                            setCtGasType(t.gas_type);
                            setCtSize(t.size_kg);
                            setCtDeposit(t.deposit_amount_mad || 120);
                            setCtPrice(t.base_sale_price_mad || 40);
                            setShowCatalogModal(true);
                          }}
                        >
                          Modifier
                        </button>
                        <button
                          type="button"
                          className="btn danger sm"
                          onClick={() => handleDeleteCatalog(t)}
                        >
                          Supprimer
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {types.length === 0 && (
                  <tr>
                    <td colSpan={5} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                      Aucun format enregistré.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Tab: Inventaire Principal */}
      {activeTab === "inventory" && (
        <>
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
                        <td style={{ fontWeight: 600 }}>{getVehiclePlate(ls.vehicle_id)}</td>
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
      )}

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
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "var(--space-4)" }}>
                    <label className="form-label" style={{ margin: 0 }}>Camion Cible *</label>
                    <button
                      type="button"
                      className="btn secondary sm"
                      style={{ padding: "1px 6px", fontSize: "0.72rem" }}
                      onClick={() => {
                        setEditingVehicle(null);
                        setVehiclePlate("");
                        setVehicleModel("");
                        setVehiclePayload(3500);
                        setShowVehicleModal(true);
                      }}
                    >
                      ＋ Nouveau Camion
                    </button>
                  </div>
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
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "var(--space-4)" }}>
                    <label className="form-label" style={{ margin: 0 }}>Dépôt Source *</label>
                    <button
                      type="button"
                      className="btn secondary sm"
                      style={{ padding: "1px 6px", fontSize: "0.72rem" }}
                      onClick={() => {
                        setDepotName("");
                        setShowDepotModal(true);
                      }}
                    >
                      ＋ Nouveau Dépôt
                    </button>
                  </div>
                  <select
                    className="input"
                    value={selectedDepotId}
                    onChange={(e) => setSelectedDepotId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un dépôt --</option>
                    {depotsList.map((l) => (
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
                  <small className="muted" style={{ display: "block", marginTop: "var(--space-4)", fontSize: "0.76rem" }}>
                    Les shifts peuvent être démarrés et gérés dans le menu "4. Carte de dispatch live".
                  </small>
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

      {/* Modal Ajout / Modification Camion */}
      {showVehicleModal && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content" style={{ maxWidth: 500 }}>
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🚛</span> {editingVehicle ? "Modifier Camion" : "Ajouter un Nouveau Camion"}
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowVehicleModal(false)}>✕</button>
            </div>

            <form onSubmit={handleSaveVehicle}>
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
                <div>
                  <label className="form-label">Numéro d'Immatriculation (Plaque) *</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="ex: 12345-A-6"
                    value={vehiclePlate}
                    onChange={(e) => setVehiclePlate(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="form-label">Marque / Modèle</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="ex: Isuzu NPR 75, Mitsubishi Canter..."
                    value={vehicleModel}
                    onChange={(e) => setVehicleModel(e.target.value)}
                  />
                </div>

                <div>
                  <label className="form-label">Charge Utile Maximale (kg)</label>
                  <input
                    type="number"
                    min={0}
                    className="input"
                    placeholder="3500"
                    value={vehiclePayload}
                    onChange={(e) => setVehiclePayload(Number(e.target.value))}
                  />
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowVehicleModal(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn" disabled={isSubmitting}>
                  {isSubmitting ? "Enregistrement..." : editingVehicle ? "✓ Mettre à jour" : "✓ Ajouter le Camion"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Ajout Dépôt Source */}
      {showDepotModal && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content" style={{ maxWidth: 500 }}>
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🏭</span> Ajouter un Dépôt Source / Entrepôt
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowDepotModal(false)}>✕</button>
            </div>

            <form onSubmit={handleSaveDepot}>
              <div>
                <label className="form-label">Nom de l'Emplacement Dépôt *</label>
                <input
                  type="text"
                  className="input"
                  placeholder="ex: Dépôt Principal Casablanca, Entrepôt Ain Sebaa..."
                  value={depotName}
                  onChange={(e) => setDepotName(e.target.value)}
                  required
                />
                <small className="muted" style={{ display: "block", marginTop: "var(--space-8)", fontSize: "0.78rem" }}>
                  Ce dépôt servira de point de départ pour les chargements camions et retours consignes.
                </small>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowDepotModal(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn" disabled={isSubmitting}>
                  {isSubmitting ? "Création..." : "✓ Créer le Dépôt"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Entrée Stock Usine */}
      {showFactoryModal && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content" style={{ maxWidth: 540 }}>
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🏭</span> Réception Stock Usine / Centre Emplisseur
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowFactoryModal(false)}>✕</button>
            </div>

            <form onSubmit={handleFactoryReceipt}>
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
                <div>
                  <label className="form-label">Dépôt Destinataire *</label>
                  <select
                    className="input"
                    value={factoryDepotId}
                    onChange={(e) => setFactoryDepotId(e.target.value)}
                    required
                  >
                    <option value="">-- Sélectionner un dépôt --</option>
                    {depotsList.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label" style={{ marginBottom: "var(--space-8)" }}>
                    Bouteilles pleines reçues (en unités)
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
                          <small className="muted">Bouteille neuve / pleine réapprovisionnée</small>
                        </div>
                        <div className="row">
                          <input
                            type="number"
                            min={0}
                            className="input"
                            style={{ width: 100, textAlign: "center", fontWeight: 700 }}
                            placeholder="0"
                            value={factoryQuantities[t.id] ?? ""}
                            onChange={(e) =>
                              setFactoryQuantities({
                                ...factoryQuantities,
                                [t.id]: Math.max(0, parseInt(e.target.value) || 0),
                              })
                            }
                          />
                          <span className="muted" style={{ fontSize: "0.85rem" }}>unités</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowFactoryModal(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn" disabled={isSubmitting}>
                  {isSubmitting ? "Enregistrement..." : "✓ Valider l'Entrée en Stock"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Ajout / Modification Format Bouteille */}
      {showCatalogModal && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content" style={{ maxWidth: 500 }}>
            <div className="panel-header">
              <h2 className="panel-title">
                <span>🏷️</span> {editingType ? "Modifier le Format" : "Nouveau Format Bouteille"}
              </h2>
              <button type="button" className="btn secondary sm" onClick={() => setShowCatalogModal(false)}>✕</button>
            </div>

            <form onSubmit={handleSaveCatalog}>
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
                <div>
                  <label className="form-label">Type de Gaz *</label>
                  <select
                    className="input"
                    value={ctGasType}
                    onChange={(e) => setCtGasType(e.target.value)}
                    required
                  >
                    <option value="butane">Butane</option>
                    <option value="propane">Propane</option>
                  </select>
                </div>

                <div>
                  <label className="form-label">Taille (kg) *</label>
                  <input
                    type="number"
                    min={1}
                    step={0.1}
                    className="input"
                    value={ctSize}
                    onChange={(e) => setCtSize(Number(e.target.value))}
                    required
                  />
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-12)" }}>
                  <div>
                    <label className="form-label">Consigne (MAD)</label>
                    <input
                      type="number"
                      min={0}
                      step={0.01}
                      className="input"
                      value={ctDeposit}
                      onChange={(e) => setCtDeposit(Number(e.target.value))}
                      required
                    />
                  </div>
                  <div>
                    <label className="form-label">Recharge (MAD) *</label>
                    <input
                      type="number"
                      min={0}
                      step={0.01}
                      className="input"
                      value={ctPrice}
                      onChange={(e) => setCtPrice(Number(e.target.value))}
                      required
                    />
                  </div>
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "var(--space-12)", marginTop: "var(--space-20)" }}>
                <button type="button" className="btn secondary" onClick={() => setShowCatalogModal(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn" disabled={isSubmitting}>
                  {isSubmitting ? "Enregistrement..." : editingType ? "✓ Mettre à jour" : "✓ Ajouter le Format"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
