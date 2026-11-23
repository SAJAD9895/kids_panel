"use client";
// Reporting play from the browser: one session per play, started → completed or abandoned.
export type Source = "feed" | "collection" | "course" | "learning_path" | "together" | "search";
export type SessionInfo = { id: string; activityId: string; lessonStepId?: string | null; source: Source; contentVersion: number; startedAt: string };

export function newSession(activityId: string, contentVersion: number, stepId?: string | null): SessionInfo {
  return { id: crypto.randomUUID(), activityId, lessonStepId: stepId ?? null, source: stepId ? "course" : "feed", contentVersion, startedAt: new Date().toISOString() };
}

/** Sends one session report. keepalive lets it finish while the page closes. */
export async function report(s: SessionInfo, status: "started" | "completed" | "abandoned", result?: Record<string, unknown> | null, responses?: unknown[]) {
  const r = await fetch("/api/play/sync", {
    method: "POST", keepalive: true, headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ session: { ...s, status, endedAt: status === "started" ? null : new Date().toISOString() }, result: result ?? null, responses }),
  });
  return r.ok ? ((await r.json()) as { status?: string; starsAwarded?: number; [k: string]: unknown }) : null;
}

export async function heartbeat(section: "watch" | "listen", seconds: number) {
  const r = await fetch("/api/play/heartbeat", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ section, seconds }) });
  return r.ok ? ((await r.json()) as { locked?: boolean; remainingSeconds?: number | null }) : null;
}

/** Sends an engine-built report (games and quizzes): the same /play/sync item the app sends. */
export async function sendItem(item: { session: Record<string, unknown>; result?: unknown; responses?: unknown[] }) {
  const r = await fetch("/api/play/sync", { method: "POST", keepalive: true, headers: { "Content-Type": "application/json" }, body: JSON.stringify(item) });
  return r.ok ? ((await r.json()) as { status?: string; rewards?: { stars?: number; badges?: unknown[] }; [k: string]: unknown }) : null;
}
