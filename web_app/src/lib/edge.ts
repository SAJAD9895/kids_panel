import "server-only";
// Calls an Edge Function as the signed-in parent (their JWT from the httpOnly cookie session).
// The functions verify the JWT and take the user id from it, never from the body.
import { env } from "./env";
import { supabaseServer } from "./supabase/server";

/** A refusal from an Edge Function (problem+json `{type, status, detail}`). */
export class EdgeError extends Error {
  constructor(public type: string, public status: number, public detail?: string) {
    super(detail ? `${type}: ${detail}` : type);
  }
}

export async function callEdge<T = unknown>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const db = await supabaseServer();
  const { data } = await db.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new EdgeError("UNAUTHORIZED", 401);
  const r = await fetch(`${env.url}/functions/v1/${path}`, {
    method: init.method ?? (init.body === undefined ? "GET" : "POST"),
    headers: { Authorization: `Bearer ${token}`, apikey: env.key, "Content-Type": "application/json" },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
    cache: "no-store",
  });
  const text = await r.text();
  const json = text ? JSON.parse(text) : null;
  if (!r.ok) throw new EdgeError(json?.type ?? "SERVER", r.status, json?.detail);
  return json as T;
}
