// Unauthorized access: one family can never reach another's children, by cookie, URL or API.
import { expect, test } from "@playwright/test";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { BOB, childId, ensureGames, passGate, signIn, sql, tokenFor } from "./helpers";

test("another family's child: not by cookie, not by URL, not by the play API", async ({ page, context }) => {
  const mia = await childId("Mia");
  const games = await ensureGames();
  await signIn(page, BOB);
  await context.addCookies([{ name: "kl_child", value: mia, url: "http://localhost:3210" }]);
  await page.goto("/kids");
  await expect(page).toHaveURL(/\/who/); // RLS: Mia isn't one of Bob's children
  await expect(page.getByRole("button", { name: "Mia" })).toHaveCount(0);
  const before = (await sql("select count(*)::int n from activity_sessions where child_id = $1", [mia]))[0].n;
  const r = await page.request.post("/api/play/sync", { data: { session: { id: crypto.randomUUID(), activityId: games.trace, source: "feed", contentVersion: 1, status: "started", startedAt: new Date().toISOString() } } });
  expect(r.status()).toBeGreaterThanOrEqual(400);
  expect((await sql("select count(*)::int n from activity_sessions where child_id = $1", [mia]))[0].n).toBe(before);
  await passGate(page);
  const rep = await page.goto(`/parents/children/${mia}/report`);
  expect(rep?.status()).toBe(404);
  const { token, url, anonKey } = await tokenFor(BOB);
  const rows = await (await fetch(`${url}/rest/v1/child_profiles?id=eq.${mia}&select=id,nickname`, { headers: { Authorization: `Bearer ${token}`, apikey: anonKey } })).json();
  expect(rows).toEqual([]);
});

test("grown-up pages need the gate; sign-in only redirects inside the app", async ({ page }) => {
  await signIn(page); // signing in opens the gate for a while (the parent just proved who they are)…
  await page.getByRole("button", { name: "Mia" }).click(); // …and handing over to a child closes it
  await expect(page).toHaveURL(/\/kids$/);
  await page.goto("/parents/privacy");
  await expect(page).toHaveURL(/\/gate\?next=%2Fparents%2Fprivacy/);
  await page.context().clearCookies();
  await page.goto("/sign-in?next=//evil.example/steal");
  await page.getByLabel("Email").first().fill("alice@example.test");
  await page.getByLabel("Password").fill("Parent-pass-123");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/localhost:3210\/who/);
});

test("the browser code holds no service key and no database address", async () => {
  const files: string[] = [];
  const walk = (d: string) => readdirSync(d).forEach((f) => { const p = join(d, f); if (statSync(p).isDirectory()) walk(p); else if (p.endsWith(".js")) files.push(p); });
  walk(".next/static");
  const all = files.map((f) => readFileSync(f, "utf8")).join("\n");
  expect(all).not.toMatch(/SUPABASE_SERVICE_ROLE_KEY|SUPABASE_DB_URL|postgres:\/\//);
  const jwts = [...all.matchAll(/eyJ[\w-]+\.(eyJ[\w-]+)\.[\w-]+/g)].map((m) => JSON.parse(Buffer.from(m[1], "base64url").toString()).role);
  expect(jwts.every((r) => r === "anon")).toBe(true);
});
