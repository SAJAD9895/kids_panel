import "server-only";
import { env } from "./env";
import { AdminError, friendly } from "./errors";
import { supabaseServer } from "./supabase/server";

/** Calls an Edge Function as the signed-in admin (their JWT; never a service key). */
export async function callEdge<T>(path: string, body: unknown): Promise<T> {
  const db = await supabaseServer();
  const { data } = await db.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new AdminError("Your session has expired. Sign in again.");
  const res = await fetch(`${env.url}/functions/v1/${path}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, apikey: env.key, "Content-Type": "application/json" },
    body: JSON.stringify(body ?? {}),
    cache: "no-store",
  });
  const out = await res.json().catch(() => ({}));
  if (!res.ok) {
    // problem+json from supabase/functions/_shared/http.ts: {type, status, detail}
    const key = String(out?.type ?? "");
    const code = ({ VALIDATION: "KL400", FORBIDDEN: "KL403", NOT_FOUND: "KL404", CONFLICT: "KL409", RATE_LIMITED: "KL429", UNAUTHORIZED: "PGRST301" } as Record<string, string>)[key] ?? "";
    throw new AdminError(friendly({ code, details: out?.detail, message: out?.detail ?? `request failed (${res.status})` }));
  }
  return out as T;
}
