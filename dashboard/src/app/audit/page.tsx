"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";

type Note = {
  id: string;
  receipt_number: string;
  outlet_id: string;
  recipient_name: string;
  total_amount_mad: number;
  created_at: string | null;
};

type Payment = {
  id: string;
  outlet_id: string;
  amount_mad: number;
  method: string;
  receipt_number: string;
  handover_status: string;
  collected_at: string;
};

type User = {
  id: string;
  phone: string;
  full_name: string;
  role: string;
};

export default function AuditPage() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [error, setError] = useState("");
  const { t, te } = useI18n();

  useEffect(() => {
    Promise.all([
      api<Note[]>("/api/v1/delivery-notes?limit=50"),
      api<Payment[]>("/api/v1/payments?limit=50"),
      api<User[]>("/api/v1/users"),
    ])
      .then(([n, p, u]) => {
        setNotes(n);
        setPayments(p);
        setUsers(u);
      })
      .catch((e) => setError(e.message));
  }, []);

  const totalPaymentsAmount = payments.reduce((sum, p) => sum + p.amount_mad, 0);

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">
            <span>⚖️</span>
            <span>{t("auditTitle")}</span>
          </h1>
          <p className="page-sub">{t("auditSub")}</p>
        </div>
        <span className="badge neutral">
          <span>ARCHIVAGE LÉGAL CNDP 10 ANS</span>
        </span>
      </header>

      {error && <div className="alert-banner error">⚠️ {error}</div>}

      {/* Asymmetric Compliance Hero Deck */}
      <section className="editorial-grid-hero">
        <div className="focal-hero-block">
          <div className="focal-hero-meta">
            <span className="kpi-label">
              <span>🔒</span> Registre Légal des Bons de Livraison (BL)
            </span>
            <span className="badge ok">SCELLÉ CRYPTOGRAPHIQUEMENT</span>
          </div>
          <div className="focal-hero-value">
            {notes.length} <span style={{ fontSize: "1.2rem", color: "var(--ink-muted)", fontWeight: 500 }}>e-BL archivés</span>
          </div>
          <p className="page-sub" style={{ marginTop: "var(--space-8)" }}>
            Bons de livraison électroniques et reçus horodatés conformément aux exigences légales marocaines de conservation 10 ans.
          </p>
        </div>

        <div className="kpi-deck">
          <div className="kpi-card" style={{ borderLeft: "3px solid var(--signal-info)" }}>
            <div className="kpi-label">
              <span>💳</span> Volume Encaissé
            </div>
            <div className="kpi-val" style={{ color: "var(--signal-info)" }}>
              {totalPaymentsAmount.toLocaleString("fr-FR")} MAD
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>Traçabilité des encaissements</small>
          </div>

          <div className="kpi-card" style={{ borderLeft: "3px solid var(--accent)" }}>
            <div className="kpi-label">
              <span>👥</span> Personnel Habilité
            </div>
            <div className="kpi-val">
              {users.length}
            </div>
            <small className="muted" style={{ fontSize: "0.76rem" }}>Comptes actifs avec rôle</small>
          </div>
        </div>
      </section>

      {/* Asymmetric Split: Staff Accounts (Left) & Delivery Receipts (Right) */}
      <section className="editorial-grid-split">
        {/* Personnel Habilité */}
        <div className="panel">
          <div className="panel-header">
            <h2 className="panel-title">
              <span>👤</span> {t("staffAccounts")} ({users.length})
            </h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{t("name")}</th>
                  <th>{t("phoneCol")}</th>
                  <th>{t("role")}</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td style={{ fontWeight: 700, color: "var(--ink-primary)" }}>{u.full_name}</td>
                    <td><code className="mono">{u.phone}</code></td>
                    <td>
                      <span className="badge info">
                        {te(u.role)}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Bons de Livraison */}
        <div className="panel" style={{ borderLeft: "3px solid var(--accent)" }}>
          <div className="panel-header">
            <h2 className="panel-title">
              <span>📜</span> {t("deliveryReceipts")}
            </h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{t("receipt")}</th>
                  <th>{t("recipient")}</th>
                  <th>{t("totalMad")}</th>
                  <th>{t("when")}</th>
                </tr>
              </thead>
              <tbody>
                {notes.map((n) => (
                  <tr key={n.id}>
                    <td><code className="mono">{n.receipt_number}</code></td>
                    <td style={{ fontWeight: 600 }}>{n.recipient_name}</td>
                    <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>{n.total_amount_mad.toLocaleString("fr-FR")} MAD</td>
                    <td><small className="muted">{n.created_at ? String(n.created_at).slice(0, 10) : "—"}</small></td>
                  </tr>
                ))}
                {notes.length === 0 && (
                  <tr>
                    <td colSpan={4} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                      {t("noDeliveryNotes")}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Traçabilité Paiements */}
      <div className="panel">
        <div className="panel-header">
          <h2 className="panel-title">
            <span>💳</span> Traçabilité des Règlements ({payments.length})
          </h2>
          <span className="badge neutral">RAPPROCHEMENT AUTOMATIQUE</span>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t("receipt")}</th>
                <th>{t("amount")}</th>
                <th>{t("method")}</th>
                <th>{t("handover")}</th>
                <th>{t("when")}</th>
              </tr>
            </thead>
            <tbody>
              {payments.map((p) => (
                <tr key={p.id}>
                  <td><code className="mono">{p.receipt_number}</code></td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700, color: "var(--ink-primary)" }}>{p.amount_mad.toLocaleString("fr-FR")} MAD</td>
                  <td>
                    <span className="badge neutral">
                      {te(p.method)}
                    </span>
                  </td>
                  <td>
                    <span
                      className={`badge ${
                        p.handover_status === "VERIFIED"
                          ? "ok"
                          : p.handover_status === "COLLECTED"
                            ? "info"
                            : "warn"
                      }`}
                    >
                      <span>
                        {p.handover_status === "VERIFIED" ? "● " : "■ "}
                        {te(p.handover_status)}
                      </span>
                    </span>
                  </td>
                  <td><code className="mono">{String(p.collected_at).slice(0, 19).replace("T", " ")}</code></td>
                </tr>
              ))}
              {payments.length === 0 && (
                <tr>
                  <td colSpan={5} className="muted" style={{ textAlign: "center", padding: "var(--space-24)" }}>
                    Aucun paiement enregistré.
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

