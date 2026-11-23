// Progress synchronisation between the web and the Flutter app. Both send the same /play/sync
// items (the web engine is a byte-for-byte port of the app's: test/unit/engine-parity) and read the
// same tables under RLS, so here we play on one side and read on the other.
import { expect, test } from "@playwright/test";
import { randomUUID } from "node:crypto";
import { chooseChild, childId, ensureGames, passGate, signIn, sql, tokenFor } from "./helpers";

test("what the phone app saves shows on the web: a video to keep watching, a game played, stars", async ({ page }) => {
  const mia = await childId("Mia");
  const [video] = await sql<{ id: string; title: string }>("select id, title->>'en' title from activities where type = 'video' and status = 'published' order by slug desc limit 1");
  const games = await ensureGames();
  const { token, url, anonKey } = await tokenFor("alice@example.test");
  const now = Date.now();
  const iso = (ms: number) => new Date(ms).toISOString();
  // exactly what the Flutter app sends (platform ios), straight to the Edge Function
  const r = await fetch(`${url}/functions/v1/play/sync`, {
    method: "POST", headers: { Authorization: `Bearer ${token}`, apikey: anonKey, "Content-Type": "application/json" },
    body: JSON.stringify({ deviceId: "iphone-test", clockOffsetMs: 0, items: [
      { session: { id: randomUUID(), childId: mia, activityId: video.id, source: "feed", platform: "ios", appVersion: "1.0.0", contentVersion: 1, status: "abandoned", startedAt: iso(now - 60_000), endedAt: iso(now - 50_000) },
        result: { completed: false, durationMs: 10_000, metrics: { positionMs: 8_000, durationMs: 30_000 } } },
      { session: { id: randomUUID(), childId: mia, activityId: games.number_recognition, source: "feed", platform: "ios", appVersion: "1.0.0", contentVersion: 1, status: "completed", startedAt: iso(now - 40_000), endedAt: iso(now - 20_000) },
        result: { completed: true, score: 100, correctCount: 1, totalCount: 1, durationMs: 20_000, metrics: { items: [{ k: "number_recognition", ok: true, w: 0, m: 0, h: 0, r: false, t: 4000 }], incorrect: 0, hints: 0, run: 1 } } },
    ] }),
  });
  expect(r.status).toBe(200);
  await signIn(page);
  await chooseChild(page, "Mia");
  await page.goto("/kids/watch");
  await expect(page.getByRole("region", { name: "Keep watching" }).getByRole("link", { name: new RegExp(video.title) })).toBeVisible();
  await page.goto(`/kids/watch/${video.id}`);
  await expect(page.getByText("Carrying on from 0:08")).toBeVisible();
  await passGate(page, `/parents/children/${mia}/report?period=day`);
  await expect(page.getByRole("table").last()).toContainText("Counting game");
});

test("what the web saves is what the app reads: same rows, same report", async ({ page }) => {
  const games = await ensureGames();
  await signIn(page);
  await chooseChild(page, "Leo");
  await page.goto(`/kids/play/${games.letter_recognition}`);
  await page.getByRole("button", { name: "Play" }).click();
  const opts = page.getByRole("group", { name: "Answers" }).getByRole("button");
  for (let i = 0; i < 3; i++) {
    await opts.nth(i).click();
    const next = page.getByRole("button", { name: /^(Next|Finish)$/ });
    await expect(next.or(page.getByRole("button", { name: "Try again" })).first()).toBeVisible();
    if (await next.isVisible()) { await next.click(); break; }
    await page.getByRole("button", { name: "Try again" }).click();
  }
  await expect(page.getByRole("heading", { name: "All done!" })).toBeVisible();
  await expect(page.getByText(/You earned \d+ stars?|Saved\./)).toBeVisible();
  // the Flutter app's own read (supabase_learning_repositories.dart), with the parent's token
  const leo = await childId("Leo");
  const { token, url, anonKey } = await tokenFor("alice@example.test");
  const rows = await (await fetch(`${url}/rest/v1/activity_sessions?select=activity_id,status,platform,activity_results(metrics)&child_id=eq.${leo}&order=started_at.desc&limit=60`,
    { headers: { Authorization: `Bearer ${token}`, apikey: anonKey } })).json();
  expect(rows.find((x: { activity_id: string }) => x.activity_id === games.letter_recognition)).toMatchObject({ status: "completed", platform: "web" });
  // stars and the daily roll-up are server-side, so the app's star count includes it
  const [{ stars }] = await sql<{ stars: number }>("select stars from child_star_totals where child_id = $1", [leo]);
  expect(Number(stars)).toBeGreaterThan(0);
  // and the parent report (the app's P04 uses the same endpoint)
  const rep = await (await fetch(`${url}/functions/v1/progress/report?childId=${leo}&period=day`, { headers: { Authorization: `Bearer ${token}`, apikey: anonKey } })).json();
  expect(rep.games.map((g: { title: string }) => g.title)).toContain("Alphabet game");
});
