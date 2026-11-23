// Rules shared with the Flutter app, ported from kids_app/lib/features/learning/domain/
// (progress_rules.dart, progress.dart). Pure functions: unit-tested in test/unit/rules.test.ts.
import type { Activity, CourseTree, Lesson } from "./data/catalog";

export type State = "completed" | "in_progress" | "available" | "locked";

/** A lesson is done when every required step is done. */
export const lessonDone = (l: Lesson, done: Set<string>) => l.steps.filter((s) => s.required).every((s) => done.has(s.id));

/** One state per lesson: open when the previous one is done AND every prerequisite is done. */
export function lessonStates(tree: CourseTree, done: Set<string>): State[] {
  const finished = new Set(tree.lessons.filter((l) => lessonDone(l, done)).map((l) => l.id));
  let previousDone = true;
  return tree.lessons.map((l) => {
    if (finished.has(l.id)) { previousDone = true; return "completed"; }
    if (previousDone && l.prerequisiteIds.every((p) => finished.has(p))) {
      previousDone = false;
      return l.steps.some((s) => done.has(s.id)) ? "in_progress" : "available";
    }
    return "locked";
  });
}

/** Steps of one lesson: done steps stay open; the first required step not done is "now";
 * later required steps wait; optional steps are open once the lesson is. */
export function stepStates(l: Lesson, lessonState: State, done: Set<string>): State[] {
  let currentFound = false;
  return l.steps.map((s) => {
    if (lessonState === "locked") return "locked";
    if (done.has(s.id)) return "completed";
    if (!s.required) return "available";
    if (!currentFound) { currentFound = true; return "available"; }
    return "locked";
  });
}

export function courseFraction(tree: CourseTree, done: Set<string>) {
  const req = tree.lessons.flatMap((l) => l.steps.filter((s) => s.required));
  return req.length ? req.filter((s) => done.has(s.id)).length / req.length : 0;
}

export type Switches = { learn: boolean; watch: boolean; listen: boolean; together: boolean; blockedCategoryIds: string[] };
export const ALL_ON: Switches = { learn: true, watch: true, listen: true, together: true, blockedCategoryIds: [] };
export const sectionOf = (type: Activity["type"]) =>
  type === "video" ? "watch" : type === "song" || type === "story" || type === "audio_story" ? "listen" : type === "together" ? "together" : type === "game" ? "games" : "learn";

/** What the child sees: their age window, the parent's section and category switches.
 * (The server refuses the rest at launch anyway: private.launch.) Games are never switched off. */
export function visibleTo(a: Activity, ageMonths: number, sw: Switches) {
  if (ageMonths < a.ageMin || ageMonths > a.ageMax) return false;
  const sec = sectionOf(a.type);
  if (sec !== "games" && sec !== "learn" && !sw[sec as "watch" | "listen" | "together"]) return false;
  if (sec !== "games" && a.categoryId && sw.blockedCategoryIds.includes(a.categoryId)) return false;
  return true;
}

export type Resume = { positionMs?: number; durationMs?: number; page?: number; pages?: number; at: string };
export const resumeFraction = (r: Resume) =>
  r.page != null && (r.pages ?? 0) > 0 ? (r.page + 1) / r.pages! : r.positionMs != null && (r.durationMs ?? 0) > 0 ? Math.min(1, r.positionMs / r.durationMs!) : 0;
export function resumeFromMetrics(m: Record<string, unknown> | null | undefined, at: string): Resume | null {
  if (!m) return null;
  const n = (v: unknown) => (typeof v === "number" ? Math.trunc(v) : undefined);
  const r: Resume = { positionMs: n(m.positionMs), durationMs: n(m.durationMs), page: n(m.page), pages: n(m.pages), at };
  return r.positionMs == null && r.page == null ? null : r;
}
/** Newest session first: the first decisive one per activity wins (finished → nothing to resume). */
export function positionsFromSessions(rows: { activity_id: string; status: string; started_at: string; ended_at: string | null; activity_results: unknown }[]) {
  const decided = new Set<string>();
  const out = new Map<string, Resume>();
  for (const r of rows) {
    if (decided.has(r.activity_id)) continue;
    if (r.status === "completed") { decided.add(r.activity_id); continue; }
    if (r.status !== "abandoned") continue;
    const res = Array.isArray(r.activity_results) ? r.activity_results[0] : r.activity_results;
    const p = resumeFromMetrics((res as { metrics?: Record<string, unknown> } | null)?.metrics, r.ended_at ?? r.started_at);
    if (p) { out.set(r.activity_id, p); decided.add(r.activity_id); }
  }
  return out;
}
/** Resume unless it's under 5 s or within the last 5 % (then start again), as in the app. */
export const worthResuming = (r: Resume | null | undefined) =>
  !!r && (r.page != null ? r.page > 0 && r.page < (r.pages ?? Infinity) - 1 : (r.positionMs ?? 0) >= 5000 && resumeFraction(r) < 0.95);
