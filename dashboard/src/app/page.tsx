"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";

type Overview = {
  active_trucks: number;
  completed_stops_today: number;
  exceptions_today: number;
  total_cash_collected_mad: number;
  unresolved_discrepancies: number;
  open_critical_incidents: number;
  active_holds: number;
};

export default function OverviewPage() {
  const [data, setData] = useState<Overview | null>(null);
  const [error, setError] = useState("");
  const { t } = useI18n();

  useEffect(() => {
    api<Overview>("/api/v1/overview")
      .then(setData)
      .catch((e) => setError(e.message));
    const id = setInterval(() => {
      api<Overview>("/api/v1/overview").then(setData).catch(() => undefined);
    }, 10000);
    return () => clearInterval(id);
  }, []);

  if (error) return <div className="alert-banner error">⚠️ {error}</div>;
  if (!data) return <p className="muted" style={{ padding: "var(--space-24)" }}>{t("loading")}</p>;

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>⚡</span>
            <span>{t("overviewTitle")}</span>
          </h1>
          <p className="page-sub">{t("overviewSub")}</p>
        </div>
        <div className="row">
          <span className="badge ok">
            <span>●</span>
            <span>SYSTÈME EN LIGNE</span>
          </span>
          <span className="badge neutral">
            <span>CASABLANCA HUB</span>
          </span>
        </div>
      </header>

      {/* Asymmetric Hero Focal Grid */}
      <section className="editorial-grid-hero" aria-label="Indicateurs clés de performance">
        {/* Primary Monolithic Command Focal Point */}
        <div className="focal-hero-block">
          <div>
            <div className="focal-hero-meta">
              <span className="kpi-label">
                <span>🚛</span> {t("activeTrucks")} & Débit Opérationnel
              </span>
              <span className="badge info">TEMPS RÉEL</span>
            </div>
            <div className="focal-hero-value">{data.active_trucks} <span style={{ fontSize: "1.2rem", color: "var(--ink-muted)", fontWeight: 500 }}>camions en rotation</span></div>
            <p className="page-sub" style={{ marginTop: "var(--space-8)", marginBottom: "var(--space-16)" }}>
              {data.completed_stops_today} livraisons de bouteilles GPL finalisées avec succès aujourd'hui sur le réseau B2B.
            </p>
          </div>

          <div style={{ borderTop: "1px solid var(--border-raw)", paddingTop: "var(--space-16)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "var(--space-12)" }}>
            <div>
              <div className="kpi-label">{t("cashCollected")}</div>
              <div style={{ fontFamily: "var(--font-headline)", fontSize: "1.5rem", fontWeight: 700, color: "var(--signal-ok)" }}>
                {data.total_cash_collected_mad.toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} <span style={{ fontSize: "0.9rem" }}>MAD</span>
              </div>
            </div>
            <Link href="/dispatch" className="btn secondary sm">
              <span>Voir Carte Live</span>
              <span>→</span>
            </Link>
          </div>
        </div>

        {/* Diagnostic High-Tension Stack */}
        <div className="kpi-deck">
          <div className={`kpi-card ${data.exceptions_today > 0 ? "alert-warn" : ""}`}>
            <div className="kpi-label">
              <span>⚠️</span> {t("exceptions")}
            </div>
            <div className="kpi-val" style={{ color: data.exceptions_today > 0 ? "var(--signal-warn)" : "var(--ink-primary)" }}>
              {data.exceptions_today}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem", marginTop: "var(--space-4)" }}>
              Arrêts non desservis
            </small>
          </div>

          <div className={`kpi-card ${data.unresolved_discrepancies > 0 ? "alert-high" : ""}`}>
            <div className="kpi-label">
              <span>⚖️</span> {t("unresolvedVariances")}
            </div>
            <div className="kpi-val" style={{ color: data.unresolved_discrepancies > 0 ? "var(--signal-danger)" : "var(--signal-ok)" }}>
              {data.unresolved_discrepancies}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem", marginTop: "var(--space-4)" }}>
              Remises à auditer
            </small>
          </div>

          <div className={`kpi-card ${data.open_critical_incidents > 0 ? "alert-high" : ""}`}>
            <div className="kpi-label">
              <span>🚨</span> {t("criticalIncidents")}
            </div>
            <div className="kpi-val" style={{ color: data.open_critical_incidents > 0 ? "var(--signal-danger)" : "var(--signal-ok)" }}>
              {data.open_critical_incidents}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem", marginTop: "var(--space-4)" }}>
              Registre ADR actif
            </small>
          </div>

          <div className="kpi-card">
            <div className="kpi-label">
              <span>🔒</span> {t("activeHolds")}
            </div>
            <div className="kpi-val">
              {data.active_holds}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem", marginTop: "var(--space-4)" }}>
              Comptes B2B bloqués
            </small>
          </div>
        </div>
      </section>

      {/* Editorial Quick Actions & Integrity Summary */}
      <div className="panel" style={{ borderLeft: "3px solid var(--border-strong)" }}>
        <div className="panel-header">
          <div>
            <h2 className="panel-title">
              <span>📋</span> Protocole de Continuité Opérationnelle
            </h2>
            <p className="panel-sub prose-limit">
              Toutes les transactions de stock, tournées d'approvisionnement et déclarations d'espèces sont horodatées et consignées de manière immuable.
            </p>
          </div>
          <div className="row">
            <Link href="/routes" className="btn secondary sm">
              <span>Tournées</span>
            </Link>
            <Link href="/stock" className="btn secondary sm">
              <span>Stock Dépôt</span>
            </Link>
            <Link href="/cash" className="btn sm">
              <span>Bureau Espèces</span>
            </Link>
          </div>
        </div>
      </div>
    </>
  );
}

