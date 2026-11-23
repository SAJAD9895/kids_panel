// Media URLs for the apps (docs/architecture/11-media-storage.md §11.3). Public thumbnails get a
// plain CDN URL; files in the private `content` and `video` buckets get short-lived signed URLs.
// The service role key is read from the Edge Function environment only — it never reaches a client.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const url = () => Deno.env.get("SUPABASE_URL")!;
let admin: ReturnType<typeof createClient> | undefined;
const client = () =>
  (admin ??= createClient(url(), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } }));

export type Asset = { bucket: string; path: string; durationMs?: number | null };

export function publicUrl(path: string): string {
  return `${url()}/storage/v1/object/public/public-assets/${path.split("/").map(encodeURIComponent).join("/")}`;
}

/** URL lifetime: 15 minutes for files fetched straight away; a video's own length + 1 hour,
 * because a player streams it in byte ranges for as long as it plays (pausing included). */
export function ttlSeconds(a: Asset): number {
  const media = a.durationMs ? Math.ceil(a.durationMs / 1000) + 3600 : 0;
  return Math.max(15 * 60, Math.min(media, 6 * 3600));
}

/** Signs every gated asset, grouped by bucket and lifetime (one Storage call per group). */
export async function signAll<T extends Asset>(assets: T[]): Promise<(T & { url: string; expiresAt: string | null })[]> {
  const out: (T & { url: string; expiresAt: string | null })[] = [];
  const groups = new Map<string, T[]>();
  for (const a of assets) {
    if (a.bucket === "public-assets") {
      out.push({ ...a, url: publicUrl(a.path), expiresAt: null });
      continue;
    }
    const key = `${a.bucket}|${ttlSeconds(a)}`;
    groups.set(key, [...(groups.get(key) ?? []), a]);
  }
  for (const [key, items] of groups) {
    const [bucket, ttl] = key.split("|");
    const { data, error } = await client().storage.from(bucket).createSignedUrls(items.map((i) => i.path), Number(ttl));
    if (error || !data) throw new Error(`sign ${bucket}: ${error?.message}`);
    const expiresAt = new Date(Date.now() + Number(ttl) * 1000).toISOString();
    items.forEach((a, i) => {
      const signed = data[i]?.signedUrl;
      if (!signed) throw new Error(`sign ${bucket}: missing ${a.path}`);
      out.push({ ...a, url: signed.startsWith("http") ? signed : `${url()}/storage/v1${signed}`, expiresAt });
    });
  }
  return out;
}
