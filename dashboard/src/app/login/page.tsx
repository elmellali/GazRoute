"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { requestOtp, verifyOtp } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";

export default function LoginPage() {
  const router = useRouter();
  const { t, locale, setLocale, dir } = useI18n();
  const [phone, setPhone] = useState("+212600000001");
  const [code, setCode] = useState("");
  const [devCode, setDevCode] = useState("");
  const [step, setStep] = useState<1 | 2>(1);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function sendOtp() {
    setError("");
    setBusy(true);
    try {
      const r = await requestOtp(phone);
      setDevCode(r.dev_code || "");
      setStep(2);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function verify() {
    setError("");
    setBusy(true);
    try {
      await verifyOtp(phone, code);
      router.replace("/");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: "var(--space-16)",
            borderBottom: "1px solid var(--border-subtle)",
            paddingBottom: "var(--space-12)",
          }}
        >
          <span className="brand-badge">⚡ AUTHENTIFICATION SÉCURISÉE</span>
          <button
            type="button"
            className="btn secondary sm"
            onClick={() => setLocale(locale === "fr" ? "ar" : "fr")}
          >
            🌐 {t("langToggle")}
          </button>
        </div>

        <h1 style={{ fontSize: "1.6rem", marginBottom: "var(--space-4)" }}>{t("loginTitle")}</h1>
        <p className="page-sub" style={{ marginBottom: "var(--space-20)" }}>
          {t("loginSub")}
        </p>

        {error && <div className="alert-banner error" style={{ marginBottom: "var(--space-16)" }}>⚠️ {error}</div>}

        {step === 1 ? (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
            <div>
              <label className="form-label">{t("phone")}</label>
              <input
                className="input"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+212600000000"
              />
            </div>
            <button
              type="button"
              className="btn"
              onClick={sendOtp}
              disabled={busy}
              style={{ width: "100%", marginTop: "var(--space-8)" }}
            >
              {busy ? "Envoi..." : `→ ${t("sendCode")}`}
            </button>
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
            <div>
              <label className="form-label">{t("otpCode")}</label>
              {devCode && (
                <div style={{ background: "var(--bg-surface-2)", border: "1px solid var(--border-raw)", padding: "var(--space-8)", marginBottom: "var(--space-8)", fontSize: "0.85rem" }}>
                  <span className="muted">{t("devCode")}:</span> <strong style={{ color: "var(--accent)", fontFamily: "var(--font-mono)" }}>{devCode}</strong>
                </div>
              )}
              <input
                className="input"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                maxLength={6}
                placeholder="000000"
                dir={dir}
                style={{ fontFamily: "var(--font-mono)", fontSize: "1.4rem", letterSpacing: "0.2em", textAlign: "center" }}
              />
            </div>
            <button
              type="button"
              className="btn"
              onClick={verify}
              disabled={busy || code.length < 4}
              style={{ width: "100%", marginTop: "var(--space-8)" }}
            >
              {busy ? "Vérification..." : `✓ ${t("verify")}`}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

