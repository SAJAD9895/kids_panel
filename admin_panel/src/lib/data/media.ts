// The media library (media_assets) and attaching files to activities (activity_media).
// Uploads: the browser puts the file in admin-staging/<own user id>/… (Storage policy), then the
// admin Edge Function checks it and moves it to its bucket (supabase/functions/admin).
import { AdminError, must, mustOne } from "../errors";
import { type Db, like, type Page, range, type Row } from "./db";

export const KINDS = ["image", "audio", "video_mp4", "subtitle", "game_pack", "pdf"] as const;
export const ROLES = ["video_main", "audio_main", "subtitle", "cover", "page_image", "page_audio", "printable_pdf"] as const;

export type Asset = {
  id: string; bucket: string; path: string; kind: string; mime: string; bytes: number; status: string;
  width: number | null; height: number | null; durationMs: number | null; locale: string | null; createdAt: string;
};
const toAsset = (m: Record<string, unknown>): Asset => ({
  id: m.id as string, bucket: m.bucket as string, path: m.object_path as string, kind: m.kind as string, mime: m.mime_type as string,
  bytes: Number(m.bytes), status: m.status as string, width: (m.width as number) ?? null, height: (m.height as number) ?? null,
  durationMs: (m.duration_ms as number) ?? null, locale: (m.locale as string) ?? null, createdAt: m.created_at as string,
});

export async function listAssets(db: Db, f: { q?: string; kind?: string; status?: string; page?: number; pageSize?: number }): Promise<Page<Asset>> {
  const r = range(f.page ?? 1, f.pageSize);
  let query = db.from("media_assets").select("*", { count: "exact" });
  if (f.q) query = query.ilike("object_path", like(f.q));
  if (f.kind) query = query.eq("kind", f.kind);
  if (f.status) query = query.eq("status", f.status);
  const res = await query.order("created_at", { ascending: false }).range(r.from, r.to);
  return { rows: must(res).map(toAsset), total: res.count ?? 0, page: r.page, pageSize: r.size };
}

/** Retire a file (it stays stored; nothing new can use it). Ready files need content.publish. */
export async function setAssetStatus(db: Db, id: string, status: "ready" | "retired") {
  mustOne(await db.from("media_assets").update({ status }).eq("id", id).select("id"));
}
export async function setAssetLocale(db: Db, id: string, locale: string | null) {
  if (locale && !/^[a-z]{2}(-[A-Z]{2})?$/.test(locale)) throw new AdminError("Use a language code like en or es-MX.");
  mustOne(await db.from("media_assets").update({ locale }).eq("id", id).select("id"));
}

export type Attachment = { role: string; locale: string; position: number; asset: Asset; text: string | null };
export async function listAttachments(db: Db, activityId: string): Promise<Attachment[]> {
  const rows = must(await db.from("activity_media").select("role, locale, position, text, media_assets(*)").eq("activity_id", activityId).order("role").order("position"));
  return rows.map((r: Row) => ({ role: r.role, locale: r.locale, position: r.position, text: (r.text as { en?: string } | null)?.en ?? null, asset: toAsset(r.media_assets) }));
}
export async function attach(db: Db, activityId: string, v: { role: string; assetId: string; locale?: string; position?: number; text?: string }) {
  if (!(ROLES as readonly string[]).includes(v.role)) throw new AdminError("Choose what the file is for.");
  must(await db.from("activity_media").insert({
    activity_id: activityId, role: v.role, asset_id: v.assetId, locale: v.locale || "und", position: v.position ?? 0,
    text: v.text ? { en: v.text } : null,
  }));
}
export async function detach(db: Db, activityId: string, role: string, locale: string, position: number) {
  must(await db.from("activity_media").delete().eq("activity_id", activityId).eq("role", role).eq("locale", locale).eq("position", position));
}

/** Upload rules (also enforced by the bucket and the Edge Function). */
export function checkUpload(file: { name: string; type: string; size: number }, maxMb: number, allowed: string[]) {
  if (!allowed.includes(file.type)) return `This kind of file (${file.type || "unknown"}) isn't accepted.`;
  if (file.size <= 0) return "The file is empty.";
  if (file.size > maxMb * 1024 * 1024) return `The file is bigger than ${maxMb} MB.`;
  if (!/^[\w .-]{1,120}$/.test(file.name)) return "Rename the file: letters, numbers, spaces, dots, dashes and _ only.";
  return null;
}
export const kindForMime = (mime: string): (typeof KINDS)[number] =>
  mime.startsWith("image/") ? "image" : mime.startsWith("audio/") ? "audio" : mime === "video/mp4" ? "video_mp4"
    : mime === "text/vtt" ? "subtitle" : mime === "application/pdf" ? "pdf" : "game_pack";
/** Where a finished upload is stored: pictures public, the rest gated (signed links). */
export const bucketFor = (kind: string) => (kind === "image" ? "public-assets" : kind === "video_mp4" || kind === "subtitle" ? "video" : "content");
