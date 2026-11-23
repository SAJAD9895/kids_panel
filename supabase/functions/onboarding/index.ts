// POST /onboarding/complete (docs/architecture/07-api-specification.md, F01).
// Creates the family account, owner profile, consents and first child in ONE transaction
// (private.onboard_family). Idempotent per user: a retry returns the same ids with created=false.
import { HttpError, json, readJson, routeParts, serve } from "../_shared/http.ts";
import { requireUser } from "../_shared/auth.ts";
import { db } from "../_shared/db.ts";
import { childInput, locale, parse, z } from "../_shared/validate.ts";

const body = z.object({
  timezone: z.string().min(1).max(64),
  country: z.string().regex(/^[A-Z]{2}$/).optional(),
  uiLocale: locale.optional(),
  contentLocale: locale.optional(),
  marketingOptIn: z.boolean().optional(),
  child: childInput,
  consents: z.array(z.object({
    // The apps send the short names "marketing" and "push"; the table stores marketing_email and
    // push_notifications (parental_consents.consent_type check), so they're translated here.
    type: z.enum(["terms", "privacy_policy", "child_data_collection", "marketing", "push", "marketing_email", "push_notifications"])
      .transform((t) => (t === "marketing" ? "marketing_email" : t === "push" ? "push_notifications" : t)),
    policyVersion: z.string().regex(/^[A-Za-z0-9._-]{1,32}$/),
    method: z.enum(["checkbox", "email_plus"]),
  })).min(3).max(5),
});

async function sha256(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, "0")).join("");
}

function userAgentClass(ua: string): string {
  if (/iPhone|iPad|iOS/i.test(ua)) return "ios";
  if (/Android/i.test(ua)) return "android";
  if (/Dart/i.test(ua)) return "app";
  return ua ? "web" : "unknown";
}

serve(async (req) => {
  const [route] = routeParts(req, "onboarding");
  if (req.method !== "POST" || route !== "complete") throw new HttpError("NOT_FOUND");

  const caller = await requireUser(req);
  const input = parse(body, await readJson(req));

  // Consent evidence is added here, never taken from the client (authentication.md §4).
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "";
  const evidence = {
    ipHash: ip ? await sha256(`${ip}:${Deno.env.get("EVIDENCE_SALT") ?? ""}`) : null,
    userAgentClass: userAgentClass(req.headers.get("user-agent") ?? ""),
    emailVerified: true, // the caller holds a session, which needs a verified email code or link
    at: new Date().toISOString(),
  };

  const [row] = await db()`
    select private.onboard_family(${caller.userId}::uuid, ${db().json({ ...input, evidence })}::jsonb) as r`;
  // TODO(M1): send the consent confirmation email (email_plus method) through Resend.
  return json(row.r, row.r.created ? 201 : 200);
});
