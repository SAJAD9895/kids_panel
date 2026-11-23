import "server-only";
// A child's progress, read as the parent (RLS: own household only). Same reads as the app.
import { ALL_ON, positionsFromSessions, type Resume, type Switches } from "../rules";
import type { Db } from "./db";

export type ChildProgress = {
  doneSteps: Set<string>; enrolled: Map<string, string>; stars: number; todayStars: number;
  played: { activityId: string; status: string; startedAt: string }[]; resume: Map<string, Resume>;
  favorites: Set<string>; switches: Switches; dailyLimitMinutes: number | null; hasPlus: boolean;
};

export async function childProgress(db: Db, childId: string, today: string): Promise<ChildProgress> {
  const [steps, enr, sess, daily, favs, rules, total, ent] = await Promise.all([
    db.from("lesson_step_completions").select("step_id").eq("child_id", childId),
    db.from("course_enrollments").select("course_id, status").eq("child_id", childId),
    db.from("activity_sessions").select("activity_id, started_at, ended_at, status, activity_results(metrics)").eq("child_id", childId).order("started_at", { ascending: false }).limit(60),
    db.from("daily_progress").select("local_date, stars").eq("child_id", childId).eq("local_date", today),
    db.from("favorites").select("activity_id").eq("child_id", childId),
    db.from("screen_time_rules").select("learn_enabled, watch_enabled, listen_enabled, together_enabled, daily_limit_minutes, blocked_category_ids").eq("child_id", childId),
    db.from("child_star_totals").select("stars").eq("child_id", childId),
    db.from("entitlements").select("active_until").eq("entitlement", "plus"),
  ]);
  for (const r of [steps, enr, sess, daily, favs, rules, total, ent]) if (r.error) throw new Error(r.error.message);
  const rule = rules.data?.[0];
  const sessions = (sess.data ?? []) as { activity_id: string; status: string; started_at: string; ended_at: string | null; activity_results: unknown }[];
  return {
    doneSteps: new Set((steps.data ?? []).map((x) => x.step_id as string)),
    enrolled: new Map((enr.data ?? []).map((x) => [x.course_id as string, x.status as string])),
    stars: Number(total.data?.[0]?.stars ?? 0),
    todayStars: Number(daily.data?.[0]?.stars ?? 0),
    played: sessions.map((s) => ({ activityId: s.activity_id, status: s.status, startedAt: s.started_at })),
    resume: positionsFromSessions(sessions),
    favorites: new Set((favs.data ?? []).map((x) => x.activity_id as string)),
    switches: rule ? { learn: rule.learn_enabled, watch: rule.watch_enabled, listen: rule.listen_enabled, together: rule.together_enabled, blockedCategoryIds: rule.blocked_category_ids ?? [] } : ALL_ON,
    dailyLimitMinutes: rule?.daily_limit_minutes ?? null,
    hasPlus: (ent.data ?? []).some((e) => !e.active_until || Date.parse(e.active_until as string) > Date.now()),
  };
}
