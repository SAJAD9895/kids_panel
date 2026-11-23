// The web app's own rules (everything else is the engine port: engine*.test.ts).
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { buddyIndex } from "@/components/buddy-art";
import type { Activity, CourseTree, Lesson } from "@/lib/data/catalog";
import { configProblems } from "@/lib/env";
import { sayError } from "@/lib/errors";
import { ageMonths, ageYears, clock, localDate, minutes, t } from "@/lib/format";
import { noticeText } from "@/lib/notices";
import { ALL_ON, courseFraction, lessonStates, positionsFromSessions, resumeFraction, stepStates, visibleTo, worthResuming } from "@/lib/rules";
import { strongPassword } from "@/lib/validation";

const act = (o: Partial<Activity> = {}): Activity => ({ id: "a", slug: "a", type: "game", title: "A", description: "", subjectId: null, ageMin: 24, ageMax: 96, seconds: null, plusOnly: false, categoryId: null, thumb: null, ...o });
const lesson = (id: string, steps: [string, boolean][], prereq: string[] = []): Lesson => ({ id, title: id, hasPrize: false, prerequisiteIds: prereq, estimatedMinutes: null,
  steps: steps.map(([sid, required], i) => ({ id: sid, position: i, type: "practice", required, activity: act({ id: `act-${sid}` }) })) });
const tree = (lessons: Lesson[]): CourseTree => ({ course: { id: "c", slug: "c", title: "C", description: "", subjectId: null, stage: "preschool", plusOnly: false, together: false, lessonCount: lessons.length }, lessons });

describe("lessons (same rules as the app's progress_rules.dart)", () => {
  const c = tree([lesson("l1", [["s1", true], ["s2", false]]), lesson("l2", [["s3", true]]), lesson("l3", [["s4", true]], ["l1"])]);
  it("the first lesson is open; later ones wait for the one before", () => {
    expect(lessonStates(c, new Set())).toEqual(["available", "locked", "locked"]);
    expect(lessonStates(c, new Set(["s1"]))).toEqual(["completed", "available", "locked"]);
    expect(lessonStates(c, new Set(["s1", "s3"]))).toEqual(["completed", "completed", "available"]);
  });
  it("optional steps don't hold a lesson back; a prerequisite must be done", () => {
    const p = tree([lesson("a", [["x", true]]), lesson("b", [["y", true]], ["z-missing"])]);
    expect(lessonStates(p, new Set(["x"]))).toEqual(["completed", "locked"]);
  });
  it("steps: the next required one is open, later required ones wait, extras are open", () => {
    const l = lesson("l", [["a", true], ["b", true], ["c", false]]);
    expect(stepStates(l, "available", new Set())).toEqual(["available", "locked", "available"]);
    expect(stepStates(l, "in_progress", new Set(["a"]))).toEqual(["completed", "available", "available"]);
    expect(stepStates(l, "locked", new Set())).toEqual(["locked", "locked", "locked"]);
  });
  it("course progress counts required steps", () => expect(courseFraction(c, new Set(["s1", "s3"]))).toBe(2 / 3));
});

describe("what a child may see", () => {
  it("their age window, the parent's switches and categories; games always on", () => {
    expect(visibleTo(act({ ageMin: 36, ageMax: 72 }), 30, ALL_ON)).toBe(false);
    expect(visibleTo(act({ type: "video" }), 48, { ...ALL_ON, watch: false })).toBe(false);
    expect(visibleTo(act({ type: "song", categoryId: "bed" }), 48, { ...ALL_ON, blockedCategoryIds: ["bed"] })).toBe(false);
    expect(visibleTo(act({ type: "game", categoryId: "bed" }), 48, { ...ALL_ON, watch: false, listen: false, blockedCategoryIds: ["bed"] })).toBe(true);
  });
});

describe("continue watching / reading", () => {
  const row = (activity_id: string, status: string, metrics: Record<string, unknown> | null, at: string) => ({ activity_id, status, started_at: at, ended_at: at, activity_results: metrics ? [{ metrics }] : [] });
  it("newest decisive session wins: finishing clears the place", () => {
    const m = positionsFromSessions([row("v", "completed", null, "2026-11-21T10:00:00Z"), row("v", "abandoned", { positionMs: 9000, durationMs: 30000 }, "2026-11-20T10:00:00Z"), row("s", "abandoned", { page: 2, pages: 6 }, "2026-11-21T09:00:00Z")]);
    expect(m.has("v")).toBe(false);
    expect(m.get("s")).toMatchObject({ page: 2, pages: 6 });
    expect(resumeFraction(m.get("s")!)).toBe(0.5);
  });
  it("not worth resuming under 5 s or in the last 5 %", () => {
    expect(worthResuming({ positionMs: 3000, durationMs: 60000, at: "" })).toBe(false);
    expect(worthResuming({ positionMs: 58000, durationMs: 60000, at: "" })).toBe(false);
    expect(worthResuming({ positionMs: 12000, durationMs: 60000, at: "" })).toBe(true);
    expect(worthResuming({ page: 0, pages: 5, at: "" })).toBe(false);
  });
});

describe("words and formats", () => {
  it("notices name the child from the device, never from the notice", () => {
    expect(noticeText("goal_reached", { childId: "c1", period: "week" }, (id) => (id === "c1" ? "Mia" : "?")).title).toBe("Mia reached this week's goal");
    expect(noticeText("weekly_progress", { children: [{ childId: "c1", learningDays: 3, activities: 7, seconds: 1200 }] }, () => "Mia").body).toBe("Mia: 3 learning days, 7 activities, 20 min");
  });
  it("server refusals in plain words", () => {
    expect(sayError("SCREEN_TIME_OVER")).toBe("That's all for today!");
    expect(sayError("VALIDATION", "nickname")).toBe("Please check: nickname.");
    expect(sayError("SOMETHING_NEW")).toMatch(/went wrong/);
  });
  it("dates, ages, durations", () => {
    expect(localDate("Asia/Dubai", new Date("2026-11-21T21:30:00Z"))).toBe("2026-11-22");
    expect(ageYears("2021-11", new Date("2026-11-21T00:00:00Z"))).toBe(5);
    expect(ageMonths("2022-07-01", new Date("2026-11-21T00:00:00Z"))).toBe(52);
    expect([minutes(45), minutes(600), clock(65000), t({ en: "Hi" }), t(null, "—")]).toEqual(["45 s", "10 min", "1:05", "Hi", "—"]);
  });
  it("buddies: avatars.key buddy-01 is art 0, as in the app", () => expect([buddyIndex("buddy-01"), buddyIndex("buddy-12"), buddyIndex(null)]).toEqual([0, 11, 0]));
  it("passwords follow the project's policy", () => {
    expect(strongPassword.safeParse("Short1").success).toBe(false);
    expect(strongPassword.safeParse("alllowercase123").success).toBe(false);
    expect(strongPassword.safeParse("Good-password-1").success).toBe(true);
  });
});

describe("configuration and design rules", () => {
  it("refuses a service role or secret key in the browser configuration", () => {
    const service = ["x", Buffer.from(JSON.stringify({ role: "service_role" })).toString("base64url"), "y"].join(".");
    expect(configProblems({ url: "https://x.supabase.co", key: service })[0]).toContain("SERVICE ROLE");
    expect(configProblems({ url: "https://x.supabase.co", key: "sb_secret_x" })[0]).toContain("SECRET");
    expect(configProblems({ url: "https://x.supabase.co", key: "sb_publishable_x" })).toEqual([]);
  });
  it("components use tokens: no hex colours, no px, arbitrary values only for token variables and selectors", () => {
    const files: string[] = [];
    const walk = (d: string) => readdirSync(d).forEach((f) => { const p = join(d, f); if (statSync(p).isDirectory()) walk(p); else if (p.endsWith(".tsx")) files.push(p); });
    walk(join(__dirname, "../../src"));
    const bad = files.flatMap((f) => {
      const s = readFileSync(f, "utf8");
      return [...s.matchAll(/#[0-9a-fA-F]{3,8}\b|\b\d+px\b|\b(?!aria-|data-)[a-z][a-z0-9-]*-\[([^\]]+)\]/g)]
        .filter((m) => !(m[1] && /var\(--|container-type/.test(m[1])))
        .map((m) => `${f}: ${m[0]}`);
    });
    expect(bad).toEqual([]);
  });
});
