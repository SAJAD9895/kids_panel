"use client";
// One media play = one session: "started" when it first plays, then "completed" (≥ 95 %, or the
// last page) or "abandoned" with where the child stopped. Positions are also kept in the browser
// every 5 s for an instant resume; the newer of the browser's and the server's wins (as in the app).
// Watching and listening send heartbeats every 30 s; when the server says the daily time is used
// up, playback stops.
import { useCallback, useEffect, useRef, useState } from "react";
import { heartbeat, newSession, report, type SessionInfo } from "@/lib/play-client";
import type { Resume } from "@/lib/rules";

const key = (childId: string, activityId: string) => `kl.resume.${childId}.${activityId}`;
export function localResume(childId: string, activityId: string): Resume | null {
  try { const v = localStorage.getItem(key(childId, activityId)); return v ? (JSON.parse(v) as Resume) : null; } catch { return null; }
}
/** The newer of two resume points. */
export const newer = (a: Resume | null, b: Resume | null) => (!a ? b : !b ? a : Date.parse(a.at) >= Date.parse(b.at) ? a : b);

export function useMediaSession(opts: { childId: string; activityId: string; contentVersion: number; stepId?: string | null; section: "watch" | "listen" }) {
  const { childId, activityId, contentVersion, stepId, section } = opts;
  const session = useRef<SessionInfo | null>(null);
  const finished = useRef(false);
  const last = useRef<Record<string, number>>({});
  const active = useRef(0);
  const [locked, setLocked] = useState(false);
  const [reward, setReward] = useState<{ stars: number } | null>(null);

  const save = useCallback((m: Record<string, number>) => {
    last.current = m;
    try { localStorage.setItem(key(childId, activityId), JSON.stringify({ ...m, at: new Date().toISOString() })); } catch { /* private mode: server copy only */ }
  }, [childId, activityId]);

  const start = useCallback(() => {
    if (session.current) return;
    session.current = newSession(activityId, contentVersion, stepId);
    void report(session.current, "started");
  }, [activityId, contentVersion, stepId]);

  const finish = useCallback(async (m: Record<string, number>, durationMs: number) => {
    if (!session.current || finished.current) return;
    finished.current = true;
    try { localStorage.removeItem(key(childId, activityId)); } catch { /* ignore */ }
    const r = await report(session.current, "completed", { completed: true, durationMs, metrics: m });
    const stars = Number((r?.rewards as { stars?: number } | undefined)?.stars ?? 0);
    setReward({ stars });
  }, [childId, activityId]);

  /** Counts active (playing) seconds for the daily limit. Call once a second while playing. */
  const tick = useCallback(() => {
    active.current += 1;
    if (active.current >= 30) {
      const n = active.current; active.current = 0;
      void heartbeat(section, n).then((h) => { if (h?.locked) setLocked(true); });
    }
  }, [section]);

  useEffect(() => {
    const leave = () => {
      if (session.current && !finished.current) {
        finished.current = true;
        void report(session.current, "abandoned", { completed: false, durationMs: Date.now() - Date.parse(session.current.startedAt), metrics: last.current });
        if (active.current > 0) void heartbeat(section, Math.min(120, active.current));
      }
    };
    window.addEventListener("pagehide", leave);
    return () => { window.removeEventListener("pagehide", leave); leave(); };
  }, [section]);

  return { start, save, finish, tick, locked, reward };
}
