import "server-only";
// GET /children/:id/rewards → private.rewards_summary (Phase 12): stars, streak, goals, badges.
import { callEdge } from "../edge";
import { t } from "../format";
import { publicUrl } from "../media";

export type Badge = { key: string; title: string; description: string; howToEarn: string; art: string | null; earnedAt: string | null; bonusStars: number };
export type Rewards = {
  balance: number; streak: { current: number; longest: number }; goals: { enabled: boolean; dailyActivities: number; weeklyDays: number };
  day: { target: number; progress: number; completedAt: string | null }; week: { target: number; progress: number; completedAt: string | null };
  badges: Badge[]; transactions: { amount: number; reason: string; at: string; badgeTitle: string | null }[];
  counts: Record<string, number>; rules: { key: string; stars: number; description: string }[];
};

export async function rewardsOf(childId: string): Promise<Rewards> {
  const r = await callEdge<Record<string, unknown>>(`children/${childId}/rewards`);
  const b = (r.badges as Record<string, unknown>[]) ?? [];
  const tx = (r.transactions as Record<string, unknown>[]) ?? [];
  return {
    balance: Number(r.balance ?? 0),
    streak: { current: Number((r.streak as Record<string, unknown>)?.current ?? 0), longest: Number((r.streak as Record<string, unknown>)?.longest ?? 0) },
    goals: r.goals as Rewards["goals"], day: r.day as Rewards["day"], week: r.week as Rewards["week"],
    badges: b.map((x) => ({ key: x.key as string, title: t(x.title), description: t(x.description), howToEarn: t(x.howToEarn), art: publicUrl(x.art as string), earnedAt: (x.earnedAt as string) ?? null, bonusStars: Number(x.bonusStars ?? 0) })),
    transactions: tx.map((x) => ({ amount: Number(x.amount), reason: x.reason as string, at: x.at as string, badgeTitle: x.badgeTitle ? t(x.badgeTitle) : null })),
    counts: (r.counts as Record<string, number>) ?? {}, rules: ((r.rules as Record<string, unknown>[]) ?? []).map((x) => ({ key: x.key as string, stars: Number(x.stars), description: t(x.description) })),
  };
}
