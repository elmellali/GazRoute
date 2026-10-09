"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import ForbiddenError from "@/components/ForbiddenError";

type Handover = {
  id: string;
  shift_id: string;
  expected_cash_mad: number;
  declared_cash_mad: number;
  verified_cash_mad: number | null;
  variance_mad: number | null;
  status: string;
  variance_reason?: string | null;
};

export default function CashPage() {
  const [rows, setRows] = useState<Handover[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [verifyId, setVerifyId] = useState<string | null>(null);
  const [verified, setVerified] = useState("");
  const [reason, setReason] = useState("");
  const [filterStatus, setFilterStatus] = useState<string>("ALL");
  const { t, te } = useI18n();

  function exportCsv() {
    if (filteredRows.length === 0) return;
    const headers = ["id", "shift_id", "expected_cash_mad", "declared_cash_mad", "verified_cash_mad", "variance_mad", "status", "variance_reason"];
    const lines = filteredRows.map((r) =>
      headers.map((h) => JSON.stringify((r as unknown as Record<string, unknown>)[h] ?? "")).join(",")
    );
    const csv = [headers.join(","), ...lines].join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "journal_caisse_remises.csv";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  }

  async function load() {
    try {
      const data = await api<Handover[]>("/api/v1/handovers");
      setRows(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function verify(id: string) {
    setError("");
    setSuccess("");
    try {
      await api(`/api/v1/handovers/${id}/verify`, {
        method: "POST",
        body: JSON.stringify({
          verified_cash_mad: Number(verified),
          variance_reason: reason || null,
        }),
      });
      setSuccess("Remise en espèces vérifiée et clôturée avec succès.");
      setTimeout(() => setSuccess(""), 4000);
      setVerifyId(null);
      setVerified("");
      setReason("");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  const flaggedHandovers = rows.filter((r) => r.status === "VARIANCE_FLAGGED" || (r.variance_mad !== null && r.variance_mad !== 0));
  const totalVerified = rows
    .filter((r) => r.verified_cash_mad !== null)
    .reduce((sum, r) => sum + (r.verified_cash_mad || 0), 0);

  const filteredRows = rows.filter((r) => {
    if (filterStatus === "PENDING") return r.status !== "VERIFIED";
    if (filterStatus === "VARIANCE") return r.status === "VARIANCE_FLAGGED" || (r.variance_mad !== null && r.variance_mad !== 0);
    if (filterStatus === "VERIFIED") return r.status === "VERIFIED";
    return true;
  });

  if (error && error.toLowerCase().includes("not permitted")) {
    return <ForbiddenError error={error} />;
  }

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>💵</span>
            <span>{t("cashTitle")}</span>
          </h1>
          <p className="page-sub">{t("cashSub")}</p>
        </div>
        <span className="badge neutral">
          <span>CAISSE CENTRALE</span>
        </span>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}
      {success && <div className="alert-banner success">✓ {success}</div>}

      {/* Asymmetric Financial Diagnostic Focal Deck */}
      <section className="editorial-grid-hero">
        <div className="focal-hero-block">
          <div className="focal-hero-meta">
            <span className="kpi-label">
              <span>💰</span> Espèces Clôturées en Coffre
            </span>
            <span className="badge ok">COMPTABILISÉ</span>
          </div>
          <div className="focal-hero-value">
            {totalVerified.toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} <span style={{ fontSize: "1.2rem", color: "var(--ink-muted)", fontWeight: 500 }}>MAD</span>
          </div>
          <p className="page-sub" style={{ marginTop: "var(--space-8)" }}>
            Montant physique total compté, validé et rapproché des tournées journalières.
          </p>
        </div>

        <div className="kpi-deck">
          <div className={`kpi-card ${flaggedHandovers.length > 0 ? "alert-high" : ""}`}>
            <div className="kpi-label">
              <span>⚖️</span> Écarts à Justifier
            </div>
            <div className="kpi-val" style={{ color: flaggedHandovers.length > 0 ? "var(--signal-danger)" : "var(--signal-ok)" }}>
              {flaggedHandovers.length}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>Différences déclaratif vs attendu</small>
          </div>

          <div className="kpi-card" style={{ borderLeft: "3px solid var(--signal-info)" }}>
            <div className="kpi-label">
              <span>📋</span> Total Remises Shift
            </div>
            <div className="kpi-val" style={{ color: "var(--signal-info)" }}>
              {rows.length}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>Feuilles de caisse enregistrées</small>
          </div>
        </div>
      </section>

      {/* Active Verification Dock Modal */}
      {verifyId && (
        <div className="panel" style={{ borderLeft: "3px solid var(--accent)", background: "var(--bg-surface-2)" }}>
          <div className="panel-header">
            <h2 className="panel-title">
              <span>🔍</span> {t("verifyHandover")} · Remise <code className="mono">{verifyId.slice(0, 8)}</code>
            </h2>
            <button type="button" className="btn secondary sm" onClick={() => setVerifyId(null)}>✕</button>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-12)" }}>
            <div>
              <label className="form-label">{t("verifiedCash")} *</label>
              <input
                className="input"
                type="number"
                value={verified}
                onChange={(e) => setVerified(e.target.value)}
                placeholder="Montant physique recompté (MAD)"
                required
              />
            </div>
            <div>
              <label className="form-label">{t("varianceReason")}</label>
              <input
                className="input"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder={t("variancePlaceholder")}
              />
            </div>
          </div>
          <div className="row" style={{ marginTop: "var(--space-16)", justifyContent: "flex-end" }}>
            <button type="button" className="btn secondary" onClick={() => setVerifyId(null)}>
              {t("cancel")}
            </button>
            <button type="button" className="btn" disabled={!verified} onClick={() => verify(verifyId)}>
              ✓ {t("confirm")} & Clôturer la Remise
            </button>
          </div>
        </div>
      )}

      {/* Main Ledger Table */}
      <div className="panel">
        <div className="panel-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "var(--space-8)" }}>
          <div className="row">
            <h2 className="panel-title">
              <span>📋</span> Registre des Remises d'Espèces par Shift ({filteredRows.length})
            </h2>
            <div className="row" style={{ marginLeft: "var(--space-12)" }}>
              <button
                type="button"
                className={`btn ${filterStatus === "ALL" ? "" : "secondary"} sm`}
                onClick={() => setFilterStatus("ALL")}
              >
                Tous ({rows.length})
              </button>
              <button
                type="button"
                className={`btn ${filterStatus === "PENDING" ? "" : "secondary"} sm`}
                onClick={() => setFilterStatus("PENDING")}
              >
                À Vérifier ({rows.filter((r) => r.status !== "VERIFIED").length})
              </button>
              <button
                type="button"
                className={`btn ${filterStatus === "VARIANCE" ? "" : "secondary"} sm`}
                onClick={() => setFilterStatus("VARIANCE")}
              >
                Écarts ({flaggedHandovers.length})
              </button>
              <button
                type="button"
                className={`btn ${filterStatus === "VERIFIED" ? "" : "secondary"} sm`}
                onClick={() => setFilterStatus("VERIFIED")}
              >
                Clôturés ({rows.filter((r) => r.status === "VERIFIED").length})
              </button>
            </div>
          </div>
          <button
            type="button"
            className="btn secondary sm"
            onClick={exportCsv}
          >
            📥 Exporter CSV
          </button>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t("shift")}</th>
                <th>{t("expected")}</th>
                <th>{t("declared")}</th>
                <th>{t("verified")}</th>
                <th>{t("variance")}</th>
                <th>{t("status")}</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredRows.map((h) => {
                const hasVariance = h.variance_mad !== null && h.variance_mad !== 0;
                return (
                  <tr key={h.id}>
                    <td><code className="mono">{h.shift_id.slice(0, 8)}</code></td>
                    <td style={{ fontWeight: 600 }}>{h.expected_cash_mad.toLocaleString("fr-FR")} MAD</td>
                    <td>{h.declared_cash_mad.toLocaleString("fr-FR")} MAD</td>
                    <td style={{ fontWeight: 700, color: "var(--ink-primary)" }}>{h.verified_cash_mad !== null ? `${h.verified_cash_mad.toLocaleString("fr-FR")} MAD` : "—"}</td>
                    <td
                      style={{
                        fontFamily: "var(--font-mono)",
                        fontWeight: 700,
                        color: hasVariance ? "var(--signal-danger)" : "var(--signal-ok)",
                      }}
                    >
                      {h.variance_mad !== null ? `${h.variance_mad > 0 ? "+" : ""}${h.variance_mad} MAD` : "—"}
                    </td>
                    <td>
                      <span
                        className={`badge ${
                          h.status === "VERIFIED"
                            ? "ok"
                            : h.status === "VARIANCE_FLAGGED"
                              ? "danger"
                              : "warn"
                        }`}
                      >
                        <span>
                          {h.status === "VERIFIED" ? "● " : h.status === "VARIANCE_FLAGGED" ? "▲ " : "■ "}
                          {te(h.status)}
                        </span>
                      </span>
                    </td>
                    <td>
                      {h.status !== "VERIFIED" ? (
                        <button
                          type="button"
                          className="btn secondary sm"
                          onClick={() => {
                            setVerifyId(h.id);
                            setVerified(String(h.declared_cash_mad));
                          }}
                        >
                          {t("verifyBtn")}
                        </button>
                      ) : (
                        <span className="muted" style={{ fontSize: "0.8rem" }}>Clôturé</span>
                      )}
                    </td>
                  </tr>
                );
              })}
              {rows.length === 0 && (
                <tr>
                  <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                    {t("noHandovers")}
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

