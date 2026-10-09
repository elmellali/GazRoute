"use client";

import { useI18n } from "@/components/LanguageProvider";

export default function ForbiddenError({ error }: { error: string }) {
  const { isAr } = useI18n();

  if (!error || !error.toLowerCase().includes("not permitted")) {
    return null;
  }

  return (
    <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "60vh" }}>
      <div className="card-editorial" style={{ textAlign: "center", padding: "40px", maxWidth: "480px", borderTop: "3px solid var(--signal-danger)" }}>
        <div style={{ fontSize: "48px", marginBottom: "16px" }}>🔒</div>
        <h2 className="page-title" style={{ marginBottom: "12px" }}>
          {isAr ? "وصول مرفوض" : "Accès Refusé"}
        </h2>
        <p style={{ color: "var(--ink-muted)", marginBottom: "24px", fontSize: "14px" }}>
          {isAr 
            ? "ليس لديك الصلاحيات الكافية لعرض أو إدارة هذه الصفحة. يرجى تسجيل الدخول بحساب مختلف." 
            : "Vous n'avez pas les permissions nécessaires pour afficher ou gérer cette page. Veuillez vous connecter avec un compte approprié."}
        </p>
        <div style={{ padding: "12px", background: "var(--bg-surface-3)", borderRadius: "6px", fontFamily: "var(--font-mono)", fontSize: "12px", color: "var(--signal-danger)" }}>
          {error}
        </div>
      </div>
    </div>
  );
}
