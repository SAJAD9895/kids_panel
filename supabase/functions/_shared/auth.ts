// Caller identity. The user id ALWAYS comes from the verified JWT, never from the request body.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { HttpError } from "./http.ts";

export type Caller = { userId: string; email?: string; claims: Record<string, unknown> };

const url = () => Deno.env.get("SUPABASE_URL")!;
const anonKey = () => Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!;

/** Verifies the bearer token with Supabase Auth and returns the caller. 401 if missing or invalid. */
export async function requireUser(req: Request): Promise<Caller> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) throw new HttpError("UNAUTHORIZED");
  const supabase = createClient(url(), anonKey(), { auth: { persistSession: false } });
  // getUser asks Supabase Auth to verify the token (signature, expiry, not signed out).
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) throw new HttpError("UNAUTHORIZED");
  // The token is verified above, so its payload can be read for the extra claims (role, amr, aal).
  const claims = decodePayload(token);
  if (claims.sub !== data.user.id || claims.role !== "authenticated") throw new HttpError("UNAUTHORIZED");
  return { userId: data.user.id, email: data.user.email, claims };
}

/**
 * Re-authentication (docs/backend/authentication.md §6): destructive actions need a sign-in
 * (code, password or OAuth) in the last `maxAgeSeconds`. The JWT's `amr` lists each method with
 * the time it was used; a refreshed token keeps the original times, so an old session fails.
 */
export function requireRecentSignIn(caller: Caller, maxAgeSeconds = 600) {
  const amr = (caller.claims.amr as { method?: string; timestamp?: number }[] | undefined) ?? [];
  const newest = Math.max(0, ...amr.map((a) => Number(a.timestamp) || 0));
  if (Date.now() / 1000 - newest > maxAgeSeconds) {
    throw new HttpError("REAUTH_REQUIRED", "sign in again to confirm");
  }
}

function decodePayload(token: string): Record<string, unknown> {
  try {
    const part = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part.padEnd(part.length + ((4 - (part.length % 4)) % 4), "=")));
  } catch {
    throw new HttpError("UNAUTHORIZED");
  }
}
