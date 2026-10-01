"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  useSyncExternalStore,
  ReactNode,
} from "react";
import {
  DEFAULT_LOCALE,
  Dict,
  Locale,
  dirFor,
  translate,
  translateEnum,
} from "@/lib/i18n";

type Ctx = {
  locale: Locale;
  setLocale: (l: Locale) => void;
  t: (key: string) => string;
  te: (value: string | null | undefined) => string;
  dir: "ltr" | "rtl";
};

const LanguageContext = createContext<Ctx | null>(null);
const STORAGE_KEY = "gaz_locale";

function subscribeLocale(callback: () => void) {
  window.addEventListener("storage", callback);
  return () => window.removeEventListener("storage", callback);
}

function getLocaleSnapshot(): Locale {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "fr" || saved === "ar") return saved;
  } catch {
    /* ignore */
  }
  return DEFAULT_LOCALE;
}

function getServerLocaleSnapshot(): Locale {
  return DEFAULT_LOCALE;
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const storeLocale = useSyncExternalStore(subscribeLocale, getLocaleSnapshot, getServerLocaleSnapshot);
  const [overrideLocale, setOverrideLocale] = useState<Locale | null>(null);
  const locale = overrideLocale ?? storeLocale;

  useEffect(() => {
    const html = document.documentElement;
    html.lang = locale;
    html.dir = dirFor(locale);
  }, [locale]);

  const setLocale = useCallback((l: Locale) => {
    setOverrideLocale(l);
    try {
      localStorage.setItem(STORAGE_KEY, l);
      window.dispatchEvent(new Event("storage"));
    } catch {
      /* ignore */
    }
  }, []);

  const value = useMemo<Ctx>(
    () => ({
      locale,
      setLocale,
      t: (key: string) => translate(locale, key),
      te: (v: string | null | undefined) => translateEnum(locale, v),
      dir: dirFor(locale),
    }),
    [locale, setLocale]
  );

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useI18n(): Ctx {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    const locale = DEFAULT_LOCALE;
    return {
      locale,
      setLocale: () => undefined,
      t: (key: string) => translate(locale, key),
      te: (v: string | null | undefined) => translateEnum(locale, v),
      dir: dirFor(locale),
    };
  }
  return ctx;
}

export type { Dict };
