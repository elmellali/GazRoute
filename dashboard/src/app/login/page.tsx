"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { loginWithPassword, requestOtp, verifyOtp } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";

const DEMO_ACCOUNTS = [
  { role: "Owner", name: "Youssef Benali", phone: "+212600000001", pin: "Passw0rd!" },
  { role: "Dispatcher", name: "Fatima Zahra", phone: "+212600000002", pin: "Passw0rd!" },
  { role: "Warehouse", name: "Karim Idrissi", phone: "+212600000003", pin: "Passw0rd!" },
  { role: "Agent", name: "Ahmed Alaoui", phone: "+212600000004", pin: "Passw0rd!" },
  { role: "Accountant", name: "Leila Haddad", phone: "+212600000005", pin: "Passw0rd!" },
  { role: "Auditor", name: "Inspecteur Audit", phone: "+212600000006", pin: "Passw0rd!" },
];

export default function LoginPage() {
  const router = useRouter();
  const { t, locale, setLocale, dir } = useI18n();
  const isAr = locale === "ar";

  const [phone, setPhone] = useState("+212600000001");
  const [password, setPassword] = useState("Passw0rd!");
  const [otpCode, setOtpCode] = useState("");
  const [devCode, setDevCode] = useState("");
  const [useOtpMode, setUseOtpMode] = useState(false);
  const [otpSent, setOtpSent] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  // Direct PIN / Password Login (0 DH)
  async function handlePasswordLogin(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await loginWithPassword(phone.trim(), password.trim());
      router.replace("/");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  // OTP Fallback Mode
  async function handleSendOtp() {
    setError("");
    setBusy(true);
    try {
      const r = await requestOtp(phone.trim());
      setDevCode(r.dev_code || "");
      setOtpSent(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function handleVerifyOtp(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await verifyOtp(phone.trim(), otpCode.trim());
      router.replace("/");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-wrap">
      <div className="login-card" style={{ maxWidth: "460px" }}>
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
          <span className="brand-badge">⚡ AUTHENTIFICATION 0 DH</span>
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
          {isAr
            ? "تسجيل الدخول المباشر بالرمز السري / كلمة المرور (بدون تكلفة SMS)"
            : "Accès direct par mot de passe / code PIN (Zéro coût SMS)"}
        </p>

        {error && (
          <div className="alert-banner error" style={{ marginBottom: "var(--space-16)" }}>
            ⚠️ {error}
          </div>
        )}

        {/* Mode 1: Direct PIN / Password Login (Default: 0 DH) */}
        {!useOtpMode ? (
          <form onSubmit={handlePasswordLogin} style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
            <div>
              <label className="form-label">{t("phone")}</label>
              <input
                className="input"
                required
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+212600000000"
                style={{ fontFamily: "var(--font-mono)" }}
              />
            </div>

            <div>
              <label className="form-label">{isAr ? "الرمز السري / كلمة المرور" : "Mot de passe / Code PIN (0 DH)"}</label>
              <input
                type="password"
                required
                className="input"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                style={{ fontFamily: "var(--font-mono)" }}
              />
            </div>

            <button
              type="submit"
              className="btn primary"
              disabled={busy}
              style={{ width: "100%", marginTop: "var(--space-8)" }}
            >
              {busy ? (isAr ? "جاري الدخول..." : "Connexion...") : (isAr ? "دخول مباشر (0 درهم)" : "Connexion Directe (0 DH)")}
            </button>
          </form>
        ) : (
          /* Mode 2: SMS OTP Login */
          <form onSubmit={otpSent ? handleVerifyOtp : (e) => { e.preventDefault(); handleSendOtp(); }} style={{ display: "flex", flexDirection: "column", gap: "var(--space-12)" }}>
            <div>
              <label className="form-label">{t("phone")}</label>
              <input
                className="input"
                required
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+212600000000"
                style={{ fontFamily: "var(--font-mono)" }}
              />
            </div>

            {otpSent && (
              <div>
                <label className="form-label">{t("otpCode")}</label>
                {devCode && (
                  <div className="alert-banner success" style={{ marginBottom: "var(--space-8)", padding: "6px 10px" }}>
                    ⚡ {t("devCode")}: <strong style={{ fontFamily: "var(--font-mono)", fontSize: "15px" }}>{devCode}</strong>
                  </div>
                )}
                <input
                  className="input"
                  required
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value)}
                  placeholder="000000"
                  maxLength={6}
                  style={{ fontFamily: "var(--font-mono)", textAlign: "center", fontSize: "18px", letterSpacing: "4px" }}
                />
              </div>
            )}

            <button
              type="submit"
              className="btn primary"
              disabled={busy}
              style={{ width: "100%", marginTop: "var(--space-8)" }}
            >
              {busy
                ? "Traitement..."
                : otpSent
                ? `✓ ${t("verify")}`
                : `→ ${t("sendCode")}`}
            </button>
          </form>
        )}

        {/* Toggle between Direct PIN and SMS */}
        <div style={{ textAlign: "center", marginTop: "16px" }}>
          <button
            type="button"
            className="btn secondary sm"
            style={{ fontSize: "11px" }}
            onClick={() => setUseOtpMode(!useOtpMode)}
          >
            {useOtpMode
              ? (isAr ? "التبديل إلى الدخول المباشر بالرمز السري PIN (0 درهم)" : "Revenir au mode Mot de passe / PIN (0 DH)")
              : (isAr ? "الدخول عبر رمز SMS OTP" : "Connexion par SMS OTP")}
          </button>
        </div>

        {/* Quick Demo Role Selector */}
        <div style={{ marginTop: "24px", paddingTop: "16px", borderTop: "1px solid var(--border-subtle)" }}>
          <div className="label-editorial" style={{ fontSize: "10px", color: "var(--ink-muted)", marginBottom: "8px" }}>
            {isAr ? "الحسابات التجريبية السريعة (0 DH)" : "COMPTES DE DÉMONSTRATION (CLIQUEZ POUR REMPLIR)"}
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "6px" }}>
            {DEMO_ACCOUNTS.map((acc) => (
              <button
                key={acc.role}
                type="button"
                className="btn secondary sm"
                style={{ fontSize: "11px", justifyContent: "flex-start", padding: "6px 8px" }}
                onClick={() => {
                  setPhone(acc.phone);
                  setPassword(acc.pin);
                  setUseOtpMode(false);
                }}
              >
                <span>👤</span>
                <span style={{ fontWeight: 600 }}>{acc.role}</span>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
