"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useSyncExternalStore, ReactNode } from "react";
import { setTokens } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import type { Dict, Locale } from "@/lib/i18n";

const NAV: { href: string; num: string; key: keyof Dict | string }[] = [
  { href: "/", num: "01", key: "nav1" },
  { href: "/outlets", num: "02", key: "nav2" },
  { href: "/routes", num: "03", key: "nav3" },
  { href: "/dispatch", num: "04", key: "nav4" },
  { href: "/stock", num: "05", key: "nav5" },
  { href: "/cash", num: "06", key: "nav6" },
  { href: "/safety", num: "07", key: "nav7" },
  { href: "/audit", num: "08", key: "nav8" },
  { href: "/users", num: "09", key: "nav9" },
];

function subscribeAuth(callback: () => void) {
  window.addEventListener("storage", callback);
  return () => window.removeEventListener("storage", callback);
}

function getAuthSnapshot(): string | null {
  return localStorage.getItem("gaz_tokens");
}

function getServerAuthSnapshot(): string | null {
  return "__SERVER__";
}

export default function Shell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const tokenRaw = useSyncExternalStore(subscribeAuth, getAuthSnapshot, getServerAuthSnapshot);
  const isServer = tokenRaw === "__SERVER__";
  const authed = !isServer && !!tokenRaw;
  const { t, locale, setLocale, dir } = useI18n();

  useEffect(() => {
    if (!isServer && !authed && pathname !== "/login") {
      router.replace("/login");
    }
  }, [isServer, authed, pathname, router]);

  if (isServer) return null;
  if (!authed && pathname !== "/login") return null;

  if (pathname === "/login") return <>{children}</>;

  const nextLocale: Locale = locale === "fr" ? "ar" : "fr";

  return (
    <div className="shell">
      <aside className="sidebar">
        <div>
          <div className="brand-block">
            <div className="brand-badge">⚡ TOUR DE CONTRÔLE GPL</div>
            <div className="brand-title">{t("brand")}</div>
            <div className="brand-sub">Opérations & Supervision</div>
          </div>

          <nav className="nav-group" aria-label="Navigation principale">
            {NAV.map((item) => {
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`nav-link ${isActive ? "active" : ""}`}
                >
                  <span>{t(item.key)}</span>
                  <span className="nav-indicator">{isActive ? "◀" : item.num}</span>
                </Link>
              );
            })}
          </nav>
        </div>

        <div className="sidebar-footer">
          <button
            type="button"
            className="btn secondary sm"
            style={{ width: "100%", justifyContent: "center" }}
            onClick={() => setLocale(nextLocale)}
            aria-label="Changer de langue / تغيير اللغة"
          >
            🌐 {t("langToggle")}
          </button>
          <button
            type="button"
            className="nav-link"
            style={{ justifyContent: "center", color: "var(--signal-danger)", border: "1px solid var(--border-subtle)" }}
            onClick={() => {
              setTokens(null);
              router.replace("/login");
            }}
          >
            ⏻ {t("logout")}
          </button>
        </div>
      </aside>

      <main className="main">
        <div className="main-content">{children}</div>
      </main>
    </div>
  );
}

