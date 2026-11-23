// Account operations for parents (Phase 13, docs/parent-dashboard/):
//   PUT    /account/notification-preferences   [{type, channel, enabled}]
//   POST   /account/notifications/read         {ids?}  (none = all)
//   POST   /account/export                     {childId?}  re-auth; builds the JSON export now
//   GET    /account/exports/:id/url            a fresh link (1 hour) while the export is kept (7 days)
//   POST   /account/deletion                   re-auth; deletes the account after 7 days
//   DELETE /account/deletion/:id               cancels it
// Reads (notifications, preferences, consents, subscriptions, requests) use the Data API (RLS).
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { HttpError, json, readJson, routeParts, serve } from "../_shared/http.ts";
import { requireRecentSignIn, requireUser } from "../_shared/auth.ts";
import { db } from "../_shared/db.ts";
import { parse, uuid, z } from "../_shared/validate.ts";

const prefsBody = z.array(z.object({
  type: z.string().max(40),
  channel: z.enum(["in_app", "email", "push"]),
  enabled: z.boolean(),
}).strict()).min(1).max(40);
const readBody = z.object({ ids: z.array(uuid).max(200).optional() }).strict();
const exportBody = z.object({ childId: uuid.optional() }).strict();

let admin: ReturnType<typeof createClient> | undefined;
const storage = () =>
  (admin ??= createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  })).storage.from("exports");

async function signed(path: string): Promise<{ url: string; expiresAt: string }> {
  const { data, error } = await storage().createSignedUrl(path, 3600, { download: true });
  if (error || !data) throw new Error(`sign export: ${error?.message}`);
  return { url: data.signedUrl, expiresAt: new Date(Date.now() + 3600_000).toISOString() };
}

serve(async (req) => {
  const caller = await requireUser(req);
  const [a, b, c] = routeParts(req, "account");

  if (a === "notification-preferences" && req.method === "PUT") {
    const prefs = parse(prefsBody, await readJson(req));
    const [row] = await db()`
      select private.set_notification_preferences(${caller.userId}::uuid, ${db().json(prefs)}::jsonb) as r`;
    return json(row.r);
  }
  if (a === "notifications" && b === "read" && req.method === "POST") {
    const body = parse(readBody, await readJson(req));
    const [row] = await db()`
      select private.mark_notifications_read(${caller.userId}::uuid, ${body.ids ?? null}::uuid[]) as r`;
    return json({ marked: row.r });
  }
  if (a === "export" && req.method === "POST") {
    requireRecentSignIn(caller);
    const body = parse(exportBody, await readJson(req));
    const [row] = await db()`select private.request_export(${caller.userId}::uuid, ${body.childId ?? null}::uuid) as r`;
    const { requestId, accountId } = row.r as { requestId: string; accountId: string };
    const path = `${accountId}/${requestId}.json`;
    try {
      const [p] = await db()`select private.export_payload(${requestId}::uuid) as r`;
      const file = new Blob([JSON.stringify(p.r, null, 1)], { type: "application/json" });
      const { error } = await storage().upload(path, file, { contentType: "application/json", upsert: false });
      if (error) throw new Error(error.message);
      const [f] = await db()`select private.finish_export(${requestId}::uuid, ${path}, true) as r`;
      return json({ ...(f.r as object), ...(await signed(path)) }, 201);
    } catch (err) {
      await db()`select private.finish_export(${requestId}::uuid, null, false)`;
      throw err;
    }
  }
  if (a === "exports" && b && c === "url" && req.method === "GET") {
    const id = parse(uuid, b);
    const [row] = await db()`select private.export_file(${caller.userId}::uuid, ${id}::uuid) as r`;
    return json(await signed((row.r as { path: string }).path));
  }
  if (a === "deletion" && !b && req.method === "POST") {
    requireRecentSignIn(caller);
    const [row] = await db()`select private.schedule_account_deletion(${caller.userId}::uuid) as r`;
    return json(row.r, 201);
  }
  if (a === "deletion" && b && req.method === "DELETE") {
    const id = parse(uuid, b);
    const [row] = await db()`select private.cancel_account_deletion(${caller.userId}::uuid, ${id}::uuid) as r`;
    return json(row.r);
  }
  throw new HttpError("NOT_FOUND");
});
