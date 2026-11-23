import "server-only";
// POST /play/launch: the server's gate before anything plays (published, age, Plus, the parent's
// switches and blocked categories, today's limit) and short-lived URLs for the files.
import { callEdge, EdgeError } from "../edge";
import { sayError } from "../errors";
import type { Resume } from "../rules";

export type LaunchFile = { role: string; url: string; mime: string; durationMs: number | null; position: number | null; locale: string | null; text: unknown; width: number | null; height: number | null };
export type Launch = { type: string; section: string; contentVersion: number; files: LaunchFile[]; resume: Resume | null; remainingSeconds: number | null };

export async function launch(childId: string, activityId: string, source: string): Promise<{ ok: true; launch: Launch } | { ok: false; type: string; message: string }> {
  try {
    const r = await callEdge<Record<string, unknown>>("play/launch", { body: { childId, activityId, source } });
    const assets = (r.assets as Record<string, unknown>[]) ?? [];
    return { ok: true, launch: {
      type: r.type as string, section: (r.section as string) ?? (r.type === "video" ? "watch" : "listen"), contentVersion: Number(r.contentVersion ?? 1),
      files: assets.filter((a) => a.url).map((a) => ({ role: a.role as string, url: a.url as string, mime: (a.mime as string) ?? "", durationMs: (a.durationMs as number) ?? null,
        position: (a.position as number) ?? null, locale: (a.locale as string) ?? null, text: a.text ?? null, width: (a.width as number) ?? null, height: (a.height as number) ?? null })),
      resume: (r.resume as Resume) ?? null, remainingSeconds: (r.remainingSeconds as number) ?? null,
    } };
  } catch (e) {
    if (e instanceof EdgeError) return { ok: false, type: e.type, message: sayError(e.type, e.detail) };
    throw e;
  }
}
