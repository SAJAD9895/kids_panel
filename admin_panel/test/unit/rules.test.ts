import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { configProblems } from "@/lib/env";
import { friendly } from "@/lib/errors";
import { bucketFor, checkUpload, kindForMime } from "@/lib/data/media";
import { badgeParams } from "@/lib/data/rewards";
import { parseSetting } from "@/lib/data/admin";
import { checkQuestion } from "@/lib/data/games";
import { canAny, NAV, navFor } from "@/lib/permissions";
import { activityInput, courseInput, lessonInput, lines } from "@/lib/validation";

describe("configuration", () => {
  it("refuses a service role or secret key", () => {
    const service = ["x", Buffer.from(JSON.stringify({ role: "service_role" })).toString("base64url"), "y"].join(".");
    expect(configProblems({ url: "https://x.supabase.co", key: service })).toContain("the key is the SERVICE ROLE key; use the anon / publishable key");
    expect(configProblems({ url: "https://x.supabase.co", key: "sb_secret_abc" })[0]).toContain("SECRET");
    expect(configProblems({ url: "https://x.supabase.co", key: "sb_publishable_abc" })).toEqual([]);
    expect(configProblems({ url: "", key: "" })).toHaveLength(2);
  });
});

describe("navigation follows permissions (the server re-checks)", () => {
  it("an editor sees content, not families, billing or admin users", () => {
    const hrefs = navFor(["content.read", "content.write"]).map((n) => n.href);
    expect(hrefs).toContain("/content/activities");
    expect(hrefs).not.toContain("/families");
    expect(hrefs).not.toContain("/billing");
    expect(hrefs).not.toContain("/settings/admins");
  });
  it("support sees families and requests, not content", () => {
    const hrefs = navFor(["support.read", "support.act", "billing.read"]).map((n) => n.href);
    expect(hrefs).toEqual(expect.arrayContaining(["/families", "/privacy", "/billing", "/"]));
    expect(hrefs).not.toContain("/content/activities");
  });
  it("a super admin sees everything", () => {
    expect(navFor(["content.read", "content.write", "content.publish", "support.read", "support.act", "billing.read", "billing.manage", "privacy.act", "audit.read", "admin.manage"])).toHaveLength(NAV.length);
    expect(canAny([], ["content.read"])).toBe(false);
  });
});

describe("input rules", () => {
  it("activities: ages in order, slug format", () => {
    const ok = activityInput.safeParse({ slug: "count-the-ducks", type: "game", title: "Count the ducks", ageMin: "36", ageMax: "72", difficulty: "2" });
    expect(ok.success).toBe(true);
    expect(activityInput.safeParse({ slug: "Bad Slug", type: "game", title: "x", ageMin: 1, ageMax: 2, difficulty: 1 }).success).toBe(false);
    const ages = activityInput.safeParse({ slug: "a", type: "game", title: "x", ageMin: 80, ageMax: 40, difficulty: 1 });
    expect(ages.success).toBe(false);
  });
  it("courses and lessons: objectives one per line, durations bounded, prerequisites ids", () => {
    const c = courseInput.parse({ slug: "letters", title: "Letters", stage: "preschool", difficulty: "1", sort: "0", objectives: "Know a\n\n Know b " });
    expect(c.objectives).toEqual(["Know a", "Know b"]);
    expect(lines.safeParse(Array(9).fill("x").join("\n")).success).toBe(false);
    expect(lessonInput.safeParse({ title: "L", objectives: "", estimatedMinutes: "500" }).success).toBe(false);
    expect(lessonInput.safeParse({ title: "L", objectives: "", prerequisites: ["not-a-uuid"] }).success).toBe(false);
  });
  it("quiz questions need two answers and a right one", () => {
    expect(checkQuestion({ prompt: "", type: "single_choice", difficulty: 1, imageAssetId: null, audioAssetId: null, answers: [{ text: "a", correct: false }] }))
      .toEqual(["Write the question", "Give at least two answers", "Mark the correct answer"]);
    expect(checkQuestion({ prompt: "Q", type: "single_choice", difficulty: 1, imageAssetId: null, audioAssetId: null, answers: [{ text: "a", correct: true }, { text: "b", correct: true }] })[0]).toContain("Only one");
  });
  it("badges: rule parameters", () => {
    expect(badgeParams({ key: "b", title: "t", description: "d", howToEarn: "h", rule: "streak", count: 5, bonusStars: 0, sort: 0, assetId: "x" })).toEqual({ days: 5 });
    expect(badgeParams({ key: "b", title: "t", description: "d", howToEarn: "h", rule: "subject_explorer", count: 3, subject: "numbers", bonusStars: 0, sort: 0, assetId: "x" })).toEqual({ subject: "numbers", count: 3 });
    expect(() => badgeParams({ key: "b", title: "t", description: "d", howToEarn: "h", rule: "stars", bonusStars: 0, sort: 0, assetId: "x" })).toThrow("number");
  });
  it("settings are parsed to their type", () => {
    expect(parseSetting("content.review_required", "false")).toBe(false);
    expect(parseSetting("goals.daily_default", "5")).toBe(5);
    expect(parseSetting("media.allowed_types", "image/png, video/mp4")).toEqual(["image/png", "video/mp4"]);
    expect(() => parseSetting("goals.daily_default", "five")).toThrow();
  });
  it("uploads: type, size, name", () => {
    const allowed = ["image/png", "video/mp4"];
    expect(checkUpload({ name: "a.png", type: "image/png", size: 10 }, 1, allowed)).toBeNull();
    expect(checkUpload({ name: "a.exe", type: "application/x-msdownload", size: 10 }, 1, allowed)).toContain("isn't accepted");
    expect(checkUpload({ name: "a.png", type: "image/png", size: 2 * 1024 * 1024 }, 1, allowed)).toContain("bigger than 1 MB");
    expect(checkUpload({ name: "../../etc.png", type: "image/png", size: 10 }, 1, allowed)).toContain("Rename");
    expect(bucketFor(kindForMime("image/webp"))).toBe("public-assets");
    expect(bucketFor(kindForMime("video/mp4"))).toBe("video");
    expect(bucketFor(kindForMime("audio/mp4"))).toBe("content");
  });
});

describe("error messages", () => {
  it("turns database codes into sentences", () => {
    expect(friendly({ code: "KL403", details: "content.publish required" })).toBe("Not allowed: content.publish required.");
    expect(friendly({ code: "42501" })).toContain("permission");
    expect(friendly({ code: "23505" })).toContain("already used");
    expect(friendly({ code: "KL409", details: "can't move from draft to published" })).toBe("Can't move from draft to published.");
  });
});

describe("design tokens only", () => {
  it("components use token classes: no hex colours, px values or arbitrary values", () => {
    const files: string[] = [];
    const walk = (d: string) => readdirSync(d).forEach((f) => { const p = join(d, f); if (statSync(p).isDirectory()) walk(p); else if (/\.tsx$/.test(p)) files.push(p); });
    walk(join(__dirname, "../../src"));
    const bad = files.flatMap((f) => {
      const s = readFileSync(f, "utf8");
      return [...s.matchAll(/#[0-9a-fA-F]{3,8}\b|\b\d+px\b|\b(?!aria-|data-)[a-z][a-z0-9]*-\[[^\]]+\]/g)].map((m) => `${f}: ${m[0]}`);
    }).filter((x) => !x.includes("fill=") && !x.includes("& "));
    expect(bad).toEqual([]);
  });
});
