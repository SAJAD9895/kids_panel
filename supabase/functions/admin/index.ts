// Admin operations that need the service role (Phase 14, docs/admin-cms/). The caller is an
// admin with MFA (aal2); the permission is checked from the database for that user.
//   POST /admin/media/finalize      {stagingPath, locale?, width?, height?, durationMs?}
//        checks an upload in admin-staging/<own id>/… (real type from its bytes, size, allowed
//        types from app_config), computes sha256, moves it to its bucket, registers media_assets
//   POST /admin/exports/:id/run     builds a family's requested data export (privacy.act)
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { HttpError, json, readJson, routeParts, serve } from "../_shared/http.ts";
import { type Caller, requireUser } from "../_shared/auth.ts";
import { db } from "../_shared/db.ts";
import { parse, uuid, z } from "../_shared/validate.ts";

let admin: ReturnType<typeof createClient> | undefined;
const storage = () =>
  (admin ??= createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  })).storage;

async function requirePermission(caller: Caller, perm: string) {
  if (caller.claims.aal !== "aal2") throw new HttpError("FORBIDDEN", "two-step sign-in required");
  const [row] = await db()`select private.admin_can(${caller.userId}::uuid, ${perm}) as ok`;
  if (!row.ok) throw new HttpError("FORBIDDEN", `${perm} required`);
}

const finalizeBody = z.object({
  stagingPath: z.string().min(3).max(300),
  locale: z.string().regex(/^[a-z]{2}(-[A-Z]{2})?$/).optional(),
  width: z.number().int().min(1).max(20000).optional(),
  height: z.number().int().min(1).max(20000).optional(),
  durationMs: z.number().int().min(0).max(4 * 3600 * 1000).optional(),
}).strict();

/** The real type of a file, from its first bytes (never from its name or the browser's claim). */
export function sniff(b: Uint8Array): string | null {
  const s = (i: number, n: number) => String.fromCharCode(...b.slice(i, i + n));
  if (b[0] === 0x89 && s(1, 3) === "PNG") return "image/png";
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "image/jpeg";
  if (s(0, 4) === "RIFF" && s(8, 4) === "WEBP") return "image/webp";
  if (s(4, 4) === "ftyp") return ["M4A ", "M4B "].includes(s(8, 4)) ? "audio/mp4" : "video/mp4";
  if (s(0, 3) === "ID3" || (b[0] === 0xff && (b[1] & 0xe0) === 0xe0)) return "audio/mpeg";
  if (s(0, 6) === "WEBVTT" || (b[0] === 0xef && b[1] === 0xbb && b[2] === 0xbf && s(3, 6) === "WEBVTT")) return "text/vtt";
  if (s(0, 5) === "%PDF-") return "application/pdf";
  if (s(0, 4) === "PK\u0003\u0004") return "application/zip";
  const t = s(0, 1).trim();
  if (t === "{" || t === "[") return "application/json";
  return null;
}
export const kindFor = (mime: string) =>
  mime.startsWith("image/") ? "image" : mime.startsWith("audio/") ? "audio" : mime === "video/mp4" ? "video_mp4"
    : mime === "text/vtt" ? "subtitle" : mime === "application/pdf" ? "pdf" : "game_pack";
export const bucketFor = (kind: string) => (kind === "image" ? "public-assets" : kind === "video_mp4" || kind === "subtitle" ? "video" : "content");

async function sha256(b: Uint8Array) {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", b as Uint8Array<ArrayBuffer>))].map((x) => x.toString(16).padStart(2, "0")).join("");
}

serve(async (req) => {
  const caller = await requireUser(req);
  const [a, b, c] = routeParts(req, "admin");
  if (req.method !== "POST") throw new HttpError("METHOD_NOT_ALLOWED");

  if (a === "media" && b === "finalize") {
    await requirePermission(caller, "content.write");
    const body = parse(finalizeBody, await readJson(req));
    if (!body.stagingPath.startsWith(`${caller.userId}/`) || body.stagingPath.includes("..")) {
      throw new HttpError("FORBIDDEN", "not your upload");
    }
    const [cfg] = await db()`
      select (select value from public.app_config where key = 'media.max_upload_mb') as max_mb,
             (select value from public.app_config where key = 'media.allowed_types') as types`;
    const { data: blob, error } = await storage().from("admin-staging").download(body.stagingPath);
    if (error || !blob) throw new HttpError("NOT_FOUND", "upload not found");
    const bytes = new Uint8Array(await blob.arrayBuffer());
    const remove = () => storage().from("admin-staging").remove([body.stagingPath]);
    const mime = sniff(bytes);
    const allowed: string[] = Array.isArray(cfg?.types) ? cfg.types : [];
    if (!mime || !allowed.includes(mime)) {
      await remove();
      throw new HttpError("VALIDATION", `file type not accepted (${mime ?? "unknown"})`);
    }
    if (bytes.length > Number(cfg?.max_mb ?? 200) * 1024 * 1024) {
      await remove();
      throw new HttpError("VALIDATION", "file too big");
    }
    const kind = kindFor(mime);
    const bucket = bucketFor(kind);
    const name = body.stagingPath.split("/").pop()!.replace(/^[0-9a-f-]{36}-/, "").replace(/[^\w.-]+/g, "-").slice(0, 80);
    const month = new Date().toISOString().slice(0, 7);
    const path = `admin/${month}/${crypto.randomUUID()}/${name}`;
    const up = await storage().from(bucket).upload(path, bytes, { contentType: mime, upsert: false });
    if (up.error) throw new Error(`store: ${up.error.message}`);
    await remove();
    const [row] = await db()`
      select private.admin_register_media(${caller.userId}::uuid, ${db().json({
        bucket, path, kind, mime, bytes: bytes.length, sha256: await sha256(bytes), locale: body.locale,
        width: body.width, height: body.height, durationMs: body.durationMs,
      })}::jsonb) as r`;
    return json(row.r, 201);
  }

  if (a === "exports" && b && c === "run") {
    await requirePermission(caller, "privacy.act");
    const id = parse(uuid, b);
    const [req0] = await db()`
      update public.data_export_requests set status = 'processing', updated_at = now()
       where id = ${id}::uuid and status in ('requested', 'failed', 'processing')
       returning account_id`;
    if (!req0) throw new HttpError("CONFLICT", "only a requested or failed export can be built");
    const path = `${req0.account_id}/${id}.json`;
    try {
      const [p] = await db()`select private.export_payload(${id}::uuid) as r`;
      const file = new Blob([JSON.stringify(p.r, null, 1)], { type: "application/json" });
      const up = await storage().from("exports").upload(path, file, { contentType: "application/json", upsert: true });
      if (up.error) throw new Error(up.error.message);
      const [f] = await db()`select private.finish_export(${id}::uuid, ${path}, true) as r`;
      await db()`
        insert into public.audit_logs (actor_type, actor_user_id, action, entity_table, entity_id, account_id, changes)
        values ('admin', ${caller.userId}::uuid, 'export.run', 'data_export_requests', ${id}, ${req0.account_id}::uuid, '{}'::jsonb)`;
      return json(f.r);
    } catch (err) {
      await db()`select private.finish_export(${id}::uuid, null, false)`;
      throw err;
    }
  }
  throw new HttpError("NOT_FOUND");
});
