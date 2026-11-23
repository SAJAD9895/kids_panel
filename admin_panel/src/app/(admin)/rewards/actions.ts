"use server";
import { revalidatePath } from "next/cache";
import { run, values, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import { saveBadge, saveRewardRule, setBadgeStatus, type BadgeInput } from "@/lib/data/rewards";
import { slug, text, uuid } from "@/lib/validation";

export async function saveBadgeAction(id: string | undefined, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    const v = values(fd);
    const input: BadgeInput = {
      key: slug.parse(v.key), title: text(60).parse(v.title),
      description: text(200).parse(v.description), howToEarn: text(200).parse(v.howToEarn), rule: v.rule,
      count: v.count ? Number(v.count) : undefined, subject: v.subject || undefined, bonusStars: Number(v.bonusStars) || 0,
      sort: Number(v.sort) || 0, assetId: uuid.parse(v.assetId),
    };
    await saveBadge(db, input, id);
    revalidatePath("/rewards");
    return id ? "Badge saved" : "Badge added as a draft";
  });
}
export async function badgeStatus(id: string, status: "draft" | "active" | "retired", _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    await setBadgeStatus(db, id, status);
    revalidatePath("/rewards");
    return status === "active" ? "Badge active: children can earn it" : status === "retired" ? "Badge retired" : "Badge is a draft";
  });
}
export async function saveRule(ruleKey: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    const v = values(fd);
    await saveRewardRule(db, ruleKey, { stars: Number(v.stars), active: v.active === "on", description: text(200).parse(v.description) });
    revalidatePath("/rewards");
  });
}
