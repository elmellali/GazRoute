const API = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:8000";

export type Tokens = {
  access_token: string;
  refresh_token: string;
  role: string;
  tenant_id: string;
  user_id: string;
};

export function getTokens(): Tokens | null {
  if (typeof window === "undefined") return null;
  const raw = localStorage.getItem("gaz_tokens");
  if (!raw) return null;
  try {
    return JSON.parse(raw) as Tokens;
  } catch {
    return null;
  }
}

export function setTokens(t: Tokens | null) {
  if (typeof window === "undefined") return;
  if (t) localStorage.setItem("gaz_tokens", JSON.stringify(t));
  else localStorage.removeItem("gaz_tokens");
}

export async function api<T = unknown>(
  path: string,
  opts: RequestInit & { idempotencyKey?: string } = {}
): Promise<T> {
  const tokens = getTokens();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(opts.headers as Record<string, string> | undefined),
  };
  if (tokens?.access_token) {
    headers.Authorization = `Bearer ${tokens.access_token}`;
  }
  if (opts.idempotencyKey) {
    headers["Idempotency-Key"] = opts.idempotencyKey;
  }
  const res = await fetch(`${API}${path}`, {
    ...opts,
    headers,
  });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const body = await res.json();
      detail = body.detail || JSON.stringify(body);
    } catch {
      /* ignore */
    }
    throw new Error(typeof detail === "string" ? detail : JSON.stringify(detail));
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export async function requestOtp(phone: string): Promise<{ dev_code?: string; expires_in_seconds: number }> {
  return api("/api/v1/auth/otp/request", { method: "POST", body: JSON.stringify({ phone }) });
}

export async function verifyOtp(phone: string, otp_code: string): Promise<Tokens> {
  const t = await api<Tokens>("/api/v1/auth/otp/verify", {
    method: "POST",
    body: JSON.stringify({ phone, otp_code, device_id: "dashboard-web" }),
  });
  setTokens(t);
  return t;
}
