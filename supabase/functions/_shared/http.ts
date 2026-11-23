// Shared HTTP helpers for every Edge Function: CORS, JSON responses and problem+json errors.
// Error keys are the stable message keys from docs/backend/api-design.md §4.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*", // Bearer-token API (no cookies), so a wildcard origin leaks nothing
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-child-id, x-request-id",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, PUT, DELETE, OPTIONS",
};

export type ErrorKey =
  | "VALIDATION"
  | "UNAUTHORIZED"
  | "REAUTH_REQUIRED"
  | "CHILD_LIMIT"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "CONFLICT"
  | "METHOD_NOT_ALLOWED"
  | "NEEDS_PLUS"
  | "AGE_NOT_SUITABLE"
  | "SECTION_DISABLED"
  | "CATEGORY_BLOCKED"
  | "SCREEN_TIME_OVER"
  | "RATE_LIMITED"
  | "ACCOUNT_SUSPENDED"
  | "INTERNAL";

const STATUS: Record<ErrorKey, number> = {
  VALIDATION: 400,
  UNAUTHORIZED: 401,
  REAUTH_REQUIRED: 401,
  CHILD_LIMIT: 402,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  METHOD_NOT_ALLOWED: 405,
  NEEDS_PLUS: 402,
  AGE_NOT_SUITABLE: 403,
  SECTION_DISABLED: 423,
  CATEGORY_BLOCKED: 423,
  SCREEN_TIME_OVER: 423,
  RATE_LIMITED: 429,
  ACCOUNT_SUSPENDED: 403, // support restricted the family (admin CMS, Phase 14)
  INTERNAL: 500,
};

export class HttpError extends Error {
  constructor(readonly key: ErrorKey, readonly detail?: string) {
    super(key);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function noContent(): Response {
  return new Response(null, { status: 204, headers: corsHeaders });
}

export function problem(key: ErrorKey, detail?: string): Response {
  return new Response(JSON.stringify({ type: key, status: STATUS[key], detail }), {
    status: STATUS[key],
    headers: { ...corsHeaders, "Content-Type": "application/problem+json" },
  });
}

// SQLSTATE from the private.* functions → message key (api-design.md §4).
const SQLSTATE: Record<string, ErrorKey> = {
  KL400: "VALIDATION",
  KL402: "CHILD_LIMIT",
  KL403: "FORBIDDEN",
  KL404: "NOT_FOUND",
  KL409: "CONFLICT",
  KL423: "SECTION_DISABLED",
  KL429: "RATE_LIMITED",
};

/** Turns anything thrown by a handler into a safe response. Internal details are logged, never returned. */
export function toResponse(err: unknown): Response {
  if (err instanceof HttpError) return problem(err.key, err.detail);
  const code = (err as { code?: string })?.code;
  if (code && SQLSTATE[code]) {
    // The SQL functions put a user-safe reason in DETAIL (e.g. "child must be between 1 and 12 years old").
    // Some codes carry a more precise key as the MESSAGE (KL402 NEEDS_PLUS, KL423 SCREEN_TIME_OVER…).
    const message = (err as { message?: string }).message ?? "";
    const key = message in STATUS ? (message as ErrorKey) : SQLSTATE[code];
    return problem(key, (err as { detail?: string }).detail || undefined);
  }
  console.error("unhandled", err instanceof Error ? err.message : String(err));
  return problem("INTERNAL");
}

/** Wraps a handler with CORS preflight and error mapping. */
export function serve(handler: (req: Request) => Promise<Response>) {
  // LOCAL_EDGE_PORT: the local test stack only (admin_panel/test/stack). Supabase runs functions
  // without it and picks the port itself.
  const port = Deno.env.get("LOCAL_EDGE_PORT");
  const opts = port ? { port: Number(port), onListen: () => {} } : {};
  Deno.serve(opts, async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    try {
      return await handler(req);
    } catch (err) {
      return toResponse(err);
    }
  });
}

/** Path after the function name: /functions/v1/children/<id> → ["<id>"]. */
export function routeParts(req: Request, fn: string): string[] {
  const parts = new URL(req.url).pathname.split("/").filter(Boolean);
  const i = parts.indexOf(fn);
  return i === -1 ? [] : parts.slice(i + 1);
}

export async function readJson(req: Request): Promise<unknown> {
  try {
    return await req.json();
  } catch {
    throw new HttpError("VALIDATION", "body must be JSON");
  }
}
