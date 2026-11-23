// Who is signed in, checked WITHOUT a round trip to Supabase Auth on every request.
// The session's access token is signed with the project's asymmetric key (ES256); getClaims()
// verifies the signature and expiry locally with the project's public keys (JWKS). We keep those
// keys for 10 minutes per server instance instead of downloading them on each request (each
// request builds a new Supabase client, whose own cache would start empty). A key the cache
// doesn't know (rotation) makes getClaims fetch fresh keys itself. Legacy HS256 tokens, as on the
// local test stack, fall back to Auth's getUser() inside getClaims.
// Same trust as before for page decisions: the database (PostgREST/RLS) verifies the same JWT the
// same way, and the token expires after an hour; sign-out still clears the cookie at once.
import type { SupabaseClient } from "@supabase/supabase-js";
import { env } from "../env";

type Auth = SupabaseClient["auth"];
type Jwks = NonNullable<Parameters<Auth["getClaims"]>[1]>;

const TTL_MS = 10 * 60_000;
const RETRY_MS = 60_000; // after a failed download, don't retry on every request
let cache: { jwks: Jwks; until: number } | null = null;

async function projectKeys(): Promise<Jwks> {
  if (cache && cache.until > Date.now()) return cache.jwks;
  try {
    const r = await fetch(`${env.url}/auth/v1/.well-known/jwks.json`, { cache: "no-store" });
    if (!r.ok) throw new Error(String(r.status));
    const jwks = (await r.json()) as Jwks;
    cache = { jwks: { keys: jwks.keys ?? [] }, until: Date.now() + TTL_MS };
  } catch {
    cache = { jwks: { keys: [] }, until: Date.now() + RETRY_MS }; // getClaims fetches or falls back
  }
  return cache.jwks;
}

export type SessionUser = { id: string; email: string | undefined };

/** The signed-in user from a verified session token, or null. Refreshes an expired session
 * through the client's cookie handlers, as getUser() did. */
export async function verifiedUser(db: { auth: Auth }): Promise<SessionUser | null> {
  const { data, error } = await db.auth.getClaims(undefined, await projectKeys());
  const claims = data?.claims;
  if (error || !claims?.sub || claims.role !== "authenticated") return null;
  return { id: claims.sub, email: typeof claims.email === "string" ? claims.email : undefined };
}
