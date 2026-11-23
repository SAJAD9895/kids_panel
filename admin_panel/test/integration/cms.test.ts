// Integration: the admin app's data layer (the same functions the pages call) against the local
// stack — real migrations, RLS, admin_api functions, PostgREST, Storage policies and the admin
// Edge Function. Each test signs in as a role, with or without MFA.
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import * as content from "@/lib/data/content";
import * as games from "@/lib/data/games";
import * as media from "@/lib/data/media";
import * as rewards from "@/lib/data/rewards";
import * as people from "@/lib/data/people";
import * as business from "@/lib/data/business";
import * as admin from "@/lib/data/admin";
import { itemFromForm } from "@/lib/game/config";
import type { Db } from "@/lib/data/db";
import { activityInput, courseInput, lessonInput } from "@/lib/validation";
import { login, sql, stack, token, uid } from "./helpers";

let editor: Db, manager: Db, superAdmin: Db, support: Db, finance: Db, privacy: Db, editor2: Db;
const ALICE = "00000000-0000-4000-a000-0000000000a1";
const SUPER = "00000000-0000-4000-c000-000000000001";

beforeAll(async () => {
  [editor, manager, superAdmin, support, finance, privacy, editor2] = await Promise.all(
    ["editor", "manager", "super", "support", "finance", "privacy", "editor2"].map((n) => login(`${n}@admin.test`)),
  );
});

const numbers = async () => (await sql("select id from subjects where key = 'numbers'"))[0].id as string;
async function newGame(db: Db, items = true) {
  const slug = `cms-game-${uid()}`;
  const { id } = await content.saveActivity(db, activityInput.parse({
    slug, type: "game", title: "Count the ducks", subjectId: await numbers(), ageMin: "36", ageMax: "72", difficulty: "1",
  }));
  if (items) await games.saveGameConfig(db, id, { items: [itemFromForm("number_recognition", { count: "3", picture: "icon:duck" })] });
  return { id, slug };
}
const anonSees = async (slug: string) => {
  const { url, anonKey } = stack();
  const r = await fetch(`${url}/rest/v1/activities?slug=eq.${slug}&select=id,status`, { headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` } });
  return ((await r.json()) as unknown[]).length > 0;
};

describe("sign-in, MFA and who is an admin", () => {
  it("an admin with MFA gets roles and permissions", async () => {
    const me = await admin.me(manager);
    expect(me?.aal).toBe("aal2");
    expect(me?.roles).toEqual(["content_publisher"]);
    expect(me?.permissions).toEqual(expect.arrayContaining(["content.read", "content.write", "content.publish"]));
  });
  it("without the second step (aal1) nothing admin works, even with a role", async () => {
    const half = await login("manager@admin.test", false);
    expect((await admin.me(half))?.aal).toBe("aal1");
    await expect(admin.dashboard(half)).rejects.toThrow(/Not allowed/);
    await expect(content.saveActivity(half, activityInput.parse({ slug: `x-${uid()}`, type: "video", title: "x", ageMin: 1, ageMax: 2, difficulty: 1 }))).rejects.toThrow(/permission/);
    expect((await half.from("activities").select("id").eq("status", "draft")).data).toEqual([]); // drafts invisible
  });
  it("a parent is not an admin", async () => {
    const { url, anonKey } = stack();
    const { createClient } = await import("@supabase/supabase-js");
    const parent = createClient(url, anonKey, { auth: { persistSession: false } });
    await parent.auth.signInWithPassword({ email: "alice@example.test", password: "Admin-pass-123" });
    expect(await admin.me(parent as Db)).toBeNull();
    await expect(admin.dashboard(parent as Db)).rejects.toThrow();
  });
  it("wrong code: no aal2", async () => {
    const half = await login("editor@admin.test", false);
    const { data } = await half.auth.mfa.listFactors();
    const r = await half.auth.mfa.challengeAndVerify({ factorId: data!.totp[0].id, code: "000000" });
    expect(r.error).toBeTruthy();
  });
});

describe("dashboard and activity log use real data", () => {
  it("counts match the database", async () => {
    const d = await admin.dashboard(superAdmin);
    const [c] = await sql(`select (select count(*) from parent_profiles)::int p, (select count(*) from child_profiles where status = 'active')::int c,
      (select count(*) from courses)::int co, (select count(*) from lessons)::int l, (select count(*) from activities where type = 'game')::int g`);
    expect([d.parents, d.children, d.courses, d.lessons, d.games]).toEqual([c.p, c.c, c.co, c.l, c.g]);
  });
  it("support sees the dashboard but not the content activity feed", async () => {
    expect((await admin.dashboard(support)).parents).toBeGreaterThan(0);
    await expect(admin.activity(support)).rejects.toThrow(/Not allowed/);
  });
});

describe("content CRUD and the publishing workflow", () => {
  it("editor drafts a game; manager reviews, approves, publishes; the kids app sees it only then", async () => {
    const g = await newGame(editor);
    expect(await anonSees(g.slug)).toBe(false);
    await content.transition(editor, "activities", g.id, "in_review");
    await expect(content.transition(editor, "activities", g.id, "approved")).rejects.toThrow(/content.publish/);
    await content.transition(manager, "activities", g.id, "approved");
    expect(await anonSees(g.slug)).toBe(false); // approved is not live
    await content.transition(manager, "activities", g.id, "published");
    expect(await anonSees(g.slug)).toBe(true);
    // Flutter reads the game config with the parent's session: same rows the CMS wrote
    const [row] = await sql("select g.config, a.published_by from games g join activities a on a.id = g.activity_id where a.id = $1", [g.id]);
    expect(row.config.items[0].kind).toBe("number_recognition");
    expect(row.published_by).toBe("00000000-0000-4000-c000-000000000002");
    await content.transition(manager, "activities", g.id, "retired");
    expect(await anonSees(g.slug)).toBe(false);
  });

  it("validation blocks approval: a game with no items, a course with unpublished activities", async () => {
    const g = await newGame(editor, false);
    expect(await content.validateContent(editor, "activities", g.id)).toContain("The game has no items yet");
    await content.transition(editor, "activities", g.id, "in_review");
    await expect(content.transition(manager, "activities", g.id, "approved")).rejects.toThrow(/no items/);
    const c = await content.saveCourse(editor, courseInput.parse({ slug: `cms-course-${uid()}`, title: "Ducks course", stage: "preschool", difficulty: "1", sort: "5", subjectId: await numbers() }));
    const m = await content.addModule(editor, c.id, "Module 1");
    const l = await content.addLesson(editor, m.id, "Lesson 1");
    await content.addStep(editor, l.id, g.id, "practice");
    expect(await content.validateContent(editor, "courses", c.id)).toContain("1 lesson activities aren't published yet");
  });

  it("four-eyes: a manager can't approve their own last change (setting switchable)", async () => {
    const g = await newGame(manager);
    await content.transition(manager, "activities", g.id, "in_review");
    await expect(content.transition(manager, "activities", g.id, "approved")).rejects.toThrow(/someone else/);
    await content.transition(editor, "activities", g.id, "draft"); // back
    await content.transition(editor, "activities", g.id, "in_review");
    // editor's transition isn't a content change: the manager is still the last editor
    await expect(content.transition(manager, "activities", g.id, "approved")).rejects.toThrow(/someone else/);
  });

  it("sending back needs a note; impossible moves are refused", async () => {
    const g = await newGame(editor);
    await expect(content.transition(manager, "activities", g.id, "published")).rejects.toThrow(/can't move from draft to published/i);
    await content.transition(editor, "activities", g.id, "in_review");
    await expect(content.transition(manager, "activities", g.id, "draft")).rejects.toThrow(/what needs changing/);
    await content.transition(manager, "activities", g.id, "draft", "Add a hint");
    const h = await content.history(manager, "activities", g.id);
    expect(h.find((x) => x.action === "content.draft")?.changes.note).toBe("Add a hint");
    expect(h.find((x) => x.action === "content.draft")?.actor).toBe("manager@admin.test");
  });

  it("live and approved content is locked for editors; managers can change it", async () => {
    const g = await newGame(editor);
    await content.transition(editor, "activities", g.id, "in_review");
    await content.transition(manager, "activities", g.id, "approved");
    const v = activityInput.parse({ slug: g.slug, type: "game", title: "Changed", subjectId: await numbers(), ageMin: 36, ageMax: 72, difficulty: 1 });
    await expect(content.saveActivity(editor, v, g.id)).rejects.toThrow(/permission/);
    await expect(games.saveGameConfig(editor, g.id, { items: [itemFromForm("trace", { glyph: "b" })] })).rejects.toThrow(/permission/);
    await content.saveActivity(manager, v, g.id);
  });

  it("the game builder refuses a config the engine can't play", async () => {
    const g = await newGame(editor, false);
    await expect(games.saveGameConfig(editor, g.id, { items: [{ kind: "arithmetic", a: 50, b: 1 }] })).rejects.toThrow(/isn't valid/);
  });

  it("quiz: questions and answers in the shape the app reads", async () => {
    const { id } = await content.saveActivity(editor, activityInput.parse({ slug: `cms-quiz-${uid()}`, type: "quiz", title: "Letters quiz", subjectId: await numbers(), ageMin: 36, ageMax: 72, difficulty: 1 }));
    expect(await content.validateContent(editor, "activities", id)).toContain("The quiz has no questions");
    await games.saveQuestion(editor, id, { prompt: "Which is a?", type: "single_choice", difficulty: 1, imageAssetId: null, audioAssetId: null, answers: [{ text: "a", correct: true }, { text: "b", correct: false }] });
    const qs = await games.listQuestions(editor, id);
    expect(qs[0].answers.map((a) => [a.text, a.correct])).toEqual([["a", true], ["b", false]]);
    expect(await content.validateContent(editor, "activities", id)).not.toContain("The quiz has no questions");
    await expect(games.saveQuestion(editor, id, { prompt: "x", type: "single_choice", difficulty: 1, imageAssetId: null, audioAssetId: null, answers: [{ text: "a", correct: false }, { text: "b", correct: false }] })).rejects.toThrow(/correct answer/);
  });

  it("courses: modules, lessons, ordering, prerequisites (same course only)", async () => {
    const c = await content.saveCourse(editor, courseInput.parse({ slug: `cms-c-${uid()}`, title: "Course", stage: "kindergarten", difficulty: "2", sort: "1", objectives: "Count to 5\nAdd small numbers" }));
    const m = await content.addModule(editor, c.id, "M1");
    const l1 = await content.addLesson(editor, m.id, "One");
    const l2 = await content.addLesson(editor, m.id, "Two");
    await content.moveLesson(editor, l2.id, -1);
    let tree = await content.getCourse(editor, c.id);
    expect(tree.modules[0].lessons.map((l) => l.title)).toEqual(["Two", "One"]);
    expect(tree.objectives).toEqual(["Count to 5", "Add small numbers"]);
    await content.saveLesson(editor, l2.id, lessonInput.parse({ title: "Two", objectives: "Count", estimatedMinutes: "8", prerequisites: [l1.id], instructions: "Sit together" }));
    tree = await content.getCourse(editor, c.id);
    const two = tree.modules[0].lessons.find((l) => l.id === l2.id)!;
    expect([two.prerequisites, two.estimatedMinutes, two.instructions]).toEqual([[l1.id], 8, "Sit together"]);
    const other = (await sql("select l.id from lessons l join course_modules m on m.id = l.module_id where m.course_id <> $1 limit 1", [c.id]))[0].id;
    await expect(content.saveLesson(editor, l1.id, lessonInput.parse({ title: "One", objectives: "", prerequisites: [other] }))).rejects.toThrow(/same course/);
    await expect(content.saveLesson(editor, l1.id, lessonInput.parse({ title: "One", objectives: "", prerequisites: [l1.id] }))).rejects.toThrow(/own prerequisite/);
    await content.deleteCourse(editor, c.id);
  });

  it("subjects and categories: create, sub-category, enable needs a manager, delete only when unused", async () => {
    const key = `sub_${uid()}`;
    const s = await content.saveSubject(editor, { key, name: "Space", sort: 50 });
    const parent = await content.saveCategory(editor, { key: `cat_${uid()}`, name: "Stories", sort: 9, parentId: null, iconAssetId: null });
    const child = await content.saveCategory(editor, { key: `cat_${uid()}`, name: "Bedtime stories", sort: 1, parentId: parent.id, iconAssetId: null });
    expect((await content.listCategories(editor)).find((c) => c.id === child.id)?.parentId).toBe(parent.id);
    await expect(content.setCategoryEnabled(editor, parent.id, true)).rejects.toThrow(/permission/);
    await content.setCategoryEnabled(manager, parent.id, true);
    await expect(content.deleteCategory(editor, parent.id)).rejects.toThrow(); // published + has a sub-category
    await content.deleteCategory(editor, child.id);
    await content.deleteSubject(editor, s.id);
    await expect(content.deleteSubject(editor, await numbers())).rejects.toThrow(/still used/);
  });

  it("search and pagination", async () => {
    const page = await content.listActivities(editor, { q: "ducks", page: 1 });
    expect(page.rows.every((r) => r.title.toLowerCase().includes("duck") || r.slug.includes("duck"))).toBe(true);
    expect(page.total).toBeGreaterThan(0);
    const p2 = await content.listActivities(editor, { page: 2 });
    expect(p2.page).toBe(2);
  });

  it("roles: support and finance can't change content", async () => {
    await expect(content.saveSubject(support, { key: `x_${uid()}`, name: "x", sort: 1 })).rejects.toThrow(/permission/);
    await expect(content.saveSubject(finance, { key: `x_${uid()}`, name: "x", sort: 1 })).rejects.toThrow(/permission/);
  });
});

describe("media uploads (Storage policy + admin Edge Function)", () => {
  const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(64, 7)]);
  const finalize = async (db: Db, body: unknown) => {
    const r = await fetch(`${stack().url}/functions/v1/admin/media/finalize`, {
      method: "POST", headers: { Authorization: `Bearer ${await token(db)}`, "Content-Type": "application/json" }, body: JSON.stringify(body),
    });
    return { status: r.status, body: await r.json() };
  };

  it("editor uploads to their own staging folder; the function checks and registers it", async () => {
    const me = (await admin.me(editor))!;
    const path = `${me.userId}/${randomUUID()}-duck.png`;
    const up = await editor.storage.from("admin-staging").upload(path, PNG, { contentType: "image/png" });
    expect(up.error).toBeNull();
    const r = await finalize(editor, { stagingPath: path, width: 512, height: 512 });
    expect(r.status).toBe(201);
    expect(r.body.bucket).toBe("public-assets");
    const [row] = await sql("select sha256, bytes, kind, status, created_by from media_assets where id = $1", [r.body.id]);
    expect([row.kind, row.status, Number(row.bytes), row.created_by]).toEqual(["image", "ready", PNG.length, me.userId]);
    expect(row.sha256).toMatch(/^[0-9a-f]{64}$/);
    expect(existsSync(join(stack().storageDir, "public-assets", r.body.path))).toBe(true);
    expect(await sql("select 1 from storage.objects where bucket_id = 'admin-staging' and name = $1", [path])).toEqual([]);
    expect((await media.listAssets(editor, { q: "duck", kind: "image" })).rows.some((a) => a.id === r.body.id)).toBe(true);
  });

  it("refused: someone else's folder, a disguised file, a session without MFA, a non-editor", async () => {
    const other = await editor.storage.from("admin-staging").upload(`${SUPER}/${randomUUID()}-x.png`, PNG, { contentType: "image/png" });
    expect(other.error).toBeTruthy();
    const me = (await admin.me(editor))!;
    const fake = `${me.userId}/${randomUUID()}-fake.png`;
    await editor.storage.from("admin-staging").upload(fake, Buffer.from("MZ not really a picture"), { contentType: "image/png" });
    const r = await finalize(editor, { stagingPath: fake });
    expect([r.status, r.body.type]).toEqual([400, "VALIDATION"]);
    expect(await sql("select 1 from storage.objects where name = $1", [fake])).toEqual([]);
    const half = await login("editor@admin.test", false);
    expect((await half.storage.from("admin-staging").upload(`${me.userId}/${randomUUID()}-h.png`, PNG, { contentType: "image/png" })).error).toBeTruthy();
    expect((await finalize(half, { stagingPath: `${me.userId}/x.png` })).status).toBe(403);
    expect((await finalize(support, { stagingPath: `${me.userId}/x.png` })).status).toBe(403);
    expect((await finalize(editor, { stagingPath: `${SUPER}/x.png` })).status).toBe(403);
  });

  it("files attach to activities by role; retiring a ready file needs a manager", async () => {
    const [asset] = await sql("select id from media_assets where bucket = 'video' and kind = 'video_mp4' and status = 'ready' limit 1");
    const { id } = await content.saveActivity(editor, activityInput.parse({ slug: `cms-video-${uid()}`, type: "video", title: "A video", subjectId: await numbers(), ageMin: 24, ageMax: 96, difficulty: 1 }));
    expect(await content.validateContent(editor, "activities", id)).toContain("Attach a ready video file");
    await media.attach(editor, id, { role: "video_main", assetId: asset.id });
    expect(await content.validateContent(editor, "activities", id)).not.toContain("Attach a ready video file");
    expect((await media.listAttachments(editor, id))[0].role).toBe("video_main");
    await expect(media.setAssetStatus(editor, asset.id, "retired")).rejects.toThrow(/permission/);
  });
});

describe("rewards configuration", () => {
  it("badges: draft → active (manager) → retired; reward rules editable; balances never edited here", async () => {
    const [art] = await sql("select id from media_assets where object_path like 'badges/%' limit 1");
    const b = await rewards.saveBadge(editor, { key: `badge-test-${uid()}`, title: "Ten ducks", description: "Counted ten ducks", howToEarn: "Finish 10 activities", rule: "stars", count: 10, bonusStars: 1, sort: 99, assetId: art.id });
    await expect(rewards.setBadgeStatus(editor, b.id, "active")).rejects.toThrow(/permission/);
    await rewards.setBadgeStatus(manager, b.id, "active");
    expect((await rewards.listBadges(editor)).find((x) => x.id === b.id)?.status).toBe("active");
    await rewards.saveRewardRule(manager, "daily_goal_met", { stars: 2, active: true, description: "Reach the daily goal: 2 bonus stars" });
    expect((await rewards.listRewardRules(editor)).find((r) => r.key === "daily_goal_met")?.stars).toBe(2);
    await expect(rewards.saveRewardRule(support, "daily_goal_met", { stars: 9, active: true, description: "x" })).rejects.toThrow();
    const { error } = await editor.from("star_transactions").insert({ child_id: randomUUID(), amount: 5, reason: "admin_adjustment", ref_key: "x", local_date: "2026-11-21" });
    expect(error).toBeTruthy();
  });
});

describe("families, restrictions and data requests (support / privacy)", () => {
  it("support finds a family by email; children show nickname and age only", async () => {
    const r = await people.listFamilies(support, { q: "alice@" });
    expect(r.rows[0].ownerEmail).toBe("alice@example.test");
    const f = await people.getFamily(support, r.rows[0].accountId);
    expect(f.children.map((c) => c.nickname).sort()).toEqual(["Leo", "Mia"]);
    expect(JSON.stringify(f)).not.toMatch(/birth|analytics/i);
    await expect(people.listFamilies(editor, {})).rejects.toThrow(/support.read/);
  });

  it("suspending a family stops play and media; lifting it restores them; reasons are audited", async () => {
    const acc = (await sql("select account_id from parent_profiles where user_id = $1", [ALICE]))[0].account_id;
    await expect(people.setAccountStatus(support, acc, "suspended", "")).rejects.toThrow(/reason/);
    await people.setAccountStatus(support, acc, "suspended", "Fraud check requested by finance");
    const mia = (await sql("select id from child_profiles where nickname = 'Mia'"))[0].id;
    const act = (await sql("select id from activities where slug = 'shape-homes'"))[0].id;
    await expect(sql(`select private.launch($1, $2)`, [ALICE, { childId: mia, activityId: act }])).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    await expect(sql(`select private.apply_session($1, $2)`, [ALICE, { session: { id: randomUUID(), childId: mia, activityId: act, source: "feed", platform: "ios", appVersion: "1", contentVersion: 1, status: "started", startedAt: new Date().toISOString() } }])).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    await people.setAccountStatus(support, acc, "active", "Check passed");
    expect((await sql(`select private.launch($1, $2) as r`, [ALICE, { childId: mia, activityId: act }]))[0].r.activityId).toBe(act);
    const log = await admin.activity(privacy, 1, 50, "parent_accounts");
    expect(log.find((l) => l.action === "account.suspended")?.changes.reason).toBe("Fraud check requested by finance");
    await expect(people.setAccountStatus(editor, acc, "suspended", "no permission here")).rejects.toThrow(/support.act/);
  });

  it("stars added by support: positive, reasoned, once per request, audited", async () => {
    const leo = (await sql("select id from child_profiles where nickname = 'Leo'"))[0].id;
    const req = randomUUID();
    await expect(people.grantStars(support, leo, 50, "Lost sync on an old device", req)).rejects.toThrow(/1–20/);
    await expect(people.grantStars(support, leo, 3, "short", req)).rejects.toThrow(/explain/);
    const a = await people.grantStars(support, leo, 3, "Lost sync on an old device", req);
    const b = await people.grantStars(support, leo, 3, "Lost sync on an old device", req);
    expect([a.granted, b.granted, b.balance]).toEqual([true, false, a.balance]);
    await expect(people.grantStars(editor, leo, 3, "Lost sync on an old device", randomUUID())).rejects.toThrow(/support.act/);
  });

  it("privacy officer builds a requested export (Edge Function); support can't", async () => {
    const acc = (await sql("select account_id from parent_profiles where user_id = $1", [ALICE]))[0].account_id;
    const [req] = await sql("insert into data_export_requests (account_id, requested_by, status) values ($1, $2, 'requested') returning id", [acc, ALICE]);
    const run = async (db: Db) => fetch(`${stack().url}/functions/v1/admin/exports/${req.id}/run`, { method: "POST", headers: { Authorization: `Bearer ${await token(db)}`, "Content-Type": "application/json" }, body: "{}" });
    expect((await run(support)).status).toBe(403);
    const r = await run(privacy);
    expect(r.status).toBe(200);
    expect((await r.json()).status).toBe("ready");
    expect(existsSync(join(stack().storageDir, "exports", `${acc}/${req.id}.json`))).toBe(true);
    const list = await people.privacyRequests(privacy, "export");
    expect(list.find((x) => x.id === req.id)?.status).toBe("ready");
    expect((await sql("select actor_user_id from audit_logs where action = 'export.run' and entity_id = $1", [req.id]))[0].actor_user_id).toBe("00000000-0000-4000-c000-000000000006");
  });
});

describe("subscriptions (no payment processing)", () => {
  it("finance edits plan metadata; editors can't; subscriptions are read-only", async () => {
    const [plan] = await business.listPlans(finance);
    await business.savePlan(finance, plan.id, { trialDays: 14, maxChildren: 5, active: true, apple: "com.example.plus.monthly", google: "", stripe: "" });
    expect((await business.listPlans(finance)).find((p) => p.id === plan.id)?.trialDays).toBe(14);
    await expect(business.savePlan(editor, plan.id, { trialDays: 1, maxChildren: 1, active: true, apple: "", google: "", stripe: "" })).rejects.toThrow();
    const subs = await business.listSubscriptions(finance, {});
    expect(subs.total).toBeGreaterThan(0);
    const { error } = await finance.from("subscriptions").update({ status: "active" }).eq("id", subs.rows[0].id);
    expect(error).toBeTruthy();
    expect((await business.listSubscriptions(editor, {})).total).toBe(0); // RLS: not billing staff, no rows
  });
});

describe("admin users, settings and the audit log", () => {
  it("super admin grants roles; nobody changes their own; the last super admin stays", async () => {
    await admin.setRoles(superAdmin, "candidate@admin.test", ["content_editor"]);
    const users = await admin.adminUsers(superAdmin);
    expect(users.find((u) => u.email === "candidate@admin.test")?.roles).toEqual(["content_editor"]);
    await expect(admin.setRoles(superAdmin, "super@admin.test", ["content_editor"])).rejects.toThrow(/own roles/);
    await expect(admin.setAdminStatus(superAdmin, SUPER, "suspended")).rejects.toThrow(/own status/);
    await expect(admin.setRoles(manager, "candidate@admin.test", ["super_admin"])).rejects.toThrow(/admin.manage/);
    // even directly in the table, a manager can't grant themselves a role
    const me = (await admin.me(manager))!;
    expect((await manager.from("admin_user_roles").insert({ user_id: me.userId, role_key: "super_admin" })).error).toBeTruthy();
    await admin.setRoles(superAdmin, "candidate@admin.test", []);
    const log = await admin.activity(superAdmin, 1, 50, "admin_user_roles");
    expect(log.some((l) => l.action === "insert" && l.actor === "super@admin.test")).toBe(true);
  });

  it("a suspended admin loses access at once", async () => {
    await admin.setRoles(superAdmin, "editor2@admin.test", ["content_editor"]);
    await admin.setAdminStatus(superAdmin, "00000000-0000-4000-c000-000000000008", "suspended");
    expect((await admin.me(editor2))?.permissions).toEqual([]);
    await expect(content.saveSubject(editor2, { key: `x_${uid()}`, name: "x", sort: 1 })).rejects.toThrow(/permission/);
    await admin.setAdminStatus(superAdmin, "00000000-0000-4000-c000-000000000008", "active");
  });

  it("settings: validated; the rewards engine uses the default goals", async () => {
    await expect(admin.saveSetting(superAdmin, "goals.daily_default", "11")).rejects.toThrow(/1–10/);
    await expect(admin.saveSetting(manager, "goals.daily_default", "5")).rejects.toThrow();
    await admin.saveSetting(superAdmin, "goals.daily_default", "5");
    const leo = (await sql("select id from child_profiles where nickname = 'Leo'"))[0].id;
    await sql("delete from learning_goals where child_id = $1", [leo]);
    const [s] = await sql("select private.rewards_summary($1, $2) as r", [ALICE, leo]);
    expect(s.r.goals.dailyActivities).toBe(5);
    await admin.saveSetting(superAdmin, "goals.daily_default", "3");
    expect((await admin.settings(superAdmin)).find((x) => x.key === "goals.daily_default")?.value).toBe(3);
  });

  it("the audit log is append-only and readable only with audit.read", async () => {
    await expect(admin.activity(finance)).rejects.toThrow();
    expect((await superAdmin.from("audit_logs").delete().gt("id", 0)).error).toBeTruthy();
    const rows = await admin.activity(superAdmin, 1, 200);
    expect(rows.some((r) => r.action === "content.published")).toBe(true);
  });
});
