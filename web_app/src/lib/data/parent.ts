import "server-only";
// The parent dashboard's data: GET /progress/overview and /progress/report (Phase 13), the same
// endpoints and numbers as the app's parent dashboard (docs/parent-dashboard/analytics.md).
import { callEdge } from "../edge";
import type { Rewards } from "./rewards";

export type Recent = { type: string; title: string; status: string; startedAt: string; activityId: string; seconds?: number; score?: number | null; level?: string | null };
export type ChildOverview = { childId: string; recent: Recent[]; rewards: Pick<Rewards, "day" | "week" | "goals" | "streak" | "balance"> & { counts: Record<string, number> };
  secondsToday: number; secondsWeek: number; secondsTotal: number; badgesEarned: number; gamesCompleted: number; lessonsCompleted: number };
export type Overview = { today: string; unread: number; plusUntil?: string | null; children: ChildOverview[] };
export const overview = () => callEdge<Overview>("progress/overview");

export type Report = {
  childId: string; period: "day" | "week" | "month"; from: string; to: string; today: string; daysElapsed: number; scoredSessions: number;
  totals: { stars: number; seconds: number; sessions: number; completed: number; activities: number; learningDays: number };
  previous: { from: string; to: string; seconds: number; completed: number };
  daily: { date: string; seconds: number; completed: number }[];
  byType: { type: string; started: number; completed: number }[];
  bySubject: { key: string; name: string; scored: number; seconds: number; avgScore: number | null; completed: number }[];
  games: { slug: string; title: string; plays: number; completed: number; avgScore: number | null; bestScore: number | null; accuracy: number | null; levels: string[] }[];
  quizzes: { slug: string; title: string; attempts: number; avgScore: number | null; bestScore: number | null; lastScore: number | null; firstTryCorrect: number | null }[];
  skills: { key: string; name: string; group: string; band: string; mastery: number; evidence: number; practisedInPeriod: boolean }[];
  lessons: { completedTotal: number; stepsCompleted: number; completedInPeriod: number };
  goals: { enabled: boolean; dailyTarget: number; weeklyTarget: number; daysElapsed: number; daysReached: number; weeks: { weekStart: string; reached: boolean }[] };
  consistency: { weekStart: string; learningDays: number }[];
  recent: Recent[];
};
export const report = (childId: string, period: string, date?: string) =>
  callEdge<Report>(`progress/report?childId=${encodeURIComponent(childId)}&period=${encodeURIComponent(period)}${date ? `&date=${encodeURIComponent(date)}` : ""}`);

/** Strengths and things to practise: the same fixed rule as the app (ReportInsights) —
 * only with enough evidence (≥ 3 scored activities / ≥ 3 skill updates). */
export function insights(r: Report) {
  const strong = [...r.bySubject.filter((s) => s.scored >= 3 && (s.avgScore ?? 0) >= 80).map((s) => s.name), ...r.skills.filter((s) => s.evidence >= 3 && s.band === "confident").map((s) => s.name)];
  const practise = [...r.bySubject.filter((s) => s.scored >= 3 && s.avgScore !== null && s.avgScore < 60).map((s) => s.name), ...r.skills.filter((s) => s.evidence >= 3 && s.band === "getting_started").map((s) => s.name)];
  return { strong, practise };
}
