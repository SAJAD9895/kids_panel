// Rewards configuration: badges (rewards type 'badge'), reward rules, default goals. Children's
// balances are never edited here; support adds stars through admin_api.grant_stars (audited).
import { AdminError, must, mustOne } from "../errors";
import { type Db, en, withEn, type Row } from "./db";

export const BADGE_RULES = [
  { rule: "first_game", label: "Finish a first game", param: null },
  { rule: "first_lesson", label: "Finish a first lesson (island)", param: null },
  { rule: "first_course", label: "Finish a first course", param: null },
  { rule: "daily_goals", label: "Reach the daily goal N times", param: "count" },
  { rule: "weekly_goals", label: "Reach the weekly goal N times", param: "count" },
  { rule: "streak", label: "Learn N days in a row", param: "days" },
  { rule: "subject_explorer", label: "Finish N different activities in a subject", param: "count" },
  { rule: "stars", label: "Collect N activity stars", param: "count" },
] as const;

export type Badge = {
  id: string; key: string; title: string; description: string; howToEarn: string; rule: string; params: Record<string, unknown>;
  bonusStars: number; sort: number; status: string; assetId: string; artPath: string | null; earned: number;
};
export async function listBadges(db: Db): Promise<Badge[]> {
  const rows = must(await db.from("rewards")
    .select("id, key, title, description, how_to_earn, unlock_rule, rule_params, bonus_stars, sort, status, asset_id, media_assets(object_path), child_rewards(count)")
    .eq("type", "badge").order("sort"));
  return rows.map((r: Row) => ({
    id: r.id, key: r.key, title: en(r.title), description: en(r.description), howToEarn: en(r.how_to_earn), rule: r.unlock_rule,
    params: r.rule_params ?? {}, bonusStars: r.bonus_stars, sort: r.sort, status: r.status, assetId: r.asset_id,
    artPath: r.media_assets?.object_path ?? null, earned: r.child_rewards?.[0]?.count ?? 0,
  }));
}
export type BadgeInput = { key: string; title: string; description: string; howToEarn: string; rule: string; count?: number; subject?: string; bonusStars: number; sort: number; assetId: string };
export function badgeParams(v: BadgeInput): Record<string, unknown> {
  const def = BADGE_RULES.find((r) => r.rule === v.rule);
  if (!def) throw new AdminError("Choose how the badge is earned.");
  if (!def.param) return {};
  if (!v.count || v.count < 1 || v.count > 1000) throw new AdminError("Give the number (1–1000).");
  if (v.rule === "subject_explorer") {
    if (!v.subject) throw new AdminError("Choose the subject.");
    return { subject: v.subject, count: v.count };
  }
  return { [def.param]: v.count };
}
export async function saveBadge(db: Db, v: BadgeInput, id?: string) {
  if (v.bonusStars < 0 || v.bonusStars > 10) throw new AdminError("Bonus stars are 0–10.");
  const row = { key: v.key, unlock_rule: v.rule, rule_params: badgeParams(v), bonus_stars: v.bonusStars, sort: v.sort, asset_id: v.assetId };
  if (id) {
    const old = must(await db.from("rewards").select("title, description, how_to_earn").eq("id", id).single());
    return must(await db.from("rewards").update({
      ...row, title: withEn(old.title, v.title), description: withEn(old.description, v.description), how_to_earn: withEn(old.how_to_earn, v.howToEarn),
    }).eq("id", id).select("id").single());
  }
  return must(await db.from("rewards").insert({
    ...row, type: "badge", status: "draft", rarity: "common", title: { en: v.title }, description: { en: v.description }, how_to_earn: { en: v.howToEarn },
  }).select("id").single());
}
/** draft → active (children can earn it; needs content.publish) → retired (no new awards). */
export async function setBadgeStatus(db: Db, id: string, status: "draft" | "active" | "retired") {
  mustOne(await db.from("rewards").update({ status }).eq("id", id).select("id"));
}

export type RewardRule = { key: string; stars: number; active: boolean; description: string };
export async function listRewardRules(db: Db): Promise<RewardRule[]> {
  return must(await db.from("reward_rules").select("key, stars, active, description").order("stars")).map((r: Row) => ({
    key: r.key, stars: r.stars, active: r.active, description: en(r.description),
  }));
}
export async function saveRewardRule(db: Db, key: string, v: { stars: number; active: boolean; description: string }) {
  if (v.stars < 0 || v.stars > 10) throw new AdminError("Stars are 0–10.");
  const old = must(await db.from("reward_rules").select("description").eq("key", key).single());
  mustOne(await db.from("reward_rules").update({ stars: v.stars, active: v.active, description: withEn(old.description, v.description) }).eq("key", key).select("key"));
}
