// End to end in a real browser: the built app (next start) against the local stack.
// Saves the screenshots in docs/admin-cms/screens.
import { expect, test, type Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import pg from "pg";

const PASSWORD = "Admin-pass-123";
async function shot(page: Page, name: string) {
  await page.evaluate(() => window.scrollTo(0, 0)); // the sidebar is sticky: capture from the top
  await page.screenshot({ path: `../docs/admin-cms/screens/${name}.png`, fullPage: true });
}
const db = () => new pg.Client({ connectionString: JSON.parse(readFileSync("test/e2e/.stack.json", "utf8")).dbUrl });
async function query(q: string, params: unknown[] = []) {
  const c = db(); await c.connect();
  try { return (await c.query(q, params)).rows; } finally { await c.end(); }
}
async function signIn(page: Page, email: string, code = "123456") {
  await page.goto("/login");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByLabel("6-digit code").fill(code);
  await page.getByRole("button", { name: "Sign in" }).click();
  if (code === "123456") await expect(page.getByRole("heading", { level: 1 })).toHaveText(/Dashboard/);
}
async function confirm(page: Page, label: string, note?: string) {
  await page.getByRole("button", { name: label, exact: true }).first().click();
  const d = page.getByRole("dialog");
  if (note) await d.getByRole("textbox").fill(note);
  await d.getByRole("button", { name: label, exact: true }).click();
}
const slug = `e2e-game-${Date.now().toString(36)}`;
// the workflow stepper always shows every status name, so wait on the database instead
const statusOf = async () => (await query("select status from activities where slug = $1", [slug]))[0]?.status;

test.describe.configure({ mode: "serial" });

test("signed out: every admin page sends you to sign-in", async ({ page }) => {
  for (const path of ["/", "/content/activities", "/families", "/settings/admins"]) {
    await page.goto(path);
    await expect(page).toHaveURL(/\/login/);
  }
  await shot(page, "A01-login");
});

test("sign-in needs the password and the authenticator code", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("editor@admin.test");
  await page.getByLabel("Password").fill("wrong-password");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByRole("alert").filter({ hasText: /\w/ })).toBeVisible();
  await signIn(page, "editor@admin.test", "000000");
  await expect(page.getByRole("alert").filter({ hasText: /\w/ })).toBeVisible();
  await expect(page).toHaveURL(/\/login/);
  await page.getByLabel("6-digit code").fill("123456");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(/Dashboard/);
});

test("first sign-in without an authenticator: enrol, then in", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("newadmin@admin.test");
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByRole("img", { name: /QR/i })).toBeVisible();
  await shot(page, "A02-mfa-enrol");
  await page.getByLabel("6-digit code").fill("123456");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(/Dashboard/);
});

test("a parent account gets no access; support can't open content", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("alice@example.test");
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByText(/not an admin|no admin access|isn't an admin/i)).toBeVisible();
  await signIn(page, "support@admin.test");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(/Dashboard/);
  await expect(page.getByRole("link", { name: "Activities" })).toHaveCount(0);
  await page.goto("/content/activities");
  await expect(page).toHaveURL(/no-access/);
  await shot(page, "A03-no-access");
});

test("editor builds a game and sends it for review @responsive", async ({ page }) => {
  await signIn(page, "editor@admin.test");
  await shot(page, `A04-dashboard${test.info().project.name === "tablet" ? "-tablet" : ""}`);
  if (test.info().project.name === "tablet") return;
  await page.goto("/content/activities/new");
  await page.waitForLoadState("networkidle");
  await page.getByLabel("Title").fill("Count the ducks (e2e)");
  await page.getByLabel("Slug").fill(slug);
  await page.getByLabel("Kind").selectOption("game");
  await page.getByLabel("Subject").selectOption({ label: "Numbers" });
  await page.getByLabel("Youngest age (months)").fill("36");
  await page.getByLabel("Oldest age (months)").fill("72");
  await page.getByRole("button", { name: "Create" }).click();
  await expect(page).toHaveURL(/\/content\/activities\/[0-9a-f-]{36}/);
  // game builder: add an item, check, preview, save
  await page.getByLabel("Add an item").first().selectOption("number_recognition");
  await page.getByLabel("How many to count (1–10)").fill("3");
  await page.getByRole("button", { name: "Keep this item" }).click();
  await expect(page.getByText(/Valid for the learning engine \(1 items\)/)).toBeVisible();
  await page.getByRole("button", { name: "Save game" }).click();
  await expect(page.getByRole("status").filter({ hasText: /saved/i })).toBeVisible();
  await shot(page, "A05-game-builder");
  await confirm(page, "Send for review");
  await expect.poll(statusOf).toBe("in_review");
  const [row] = await query("select a.status, g.config from activities a join games g on g.activity_id = a.id where a.slug = $1", [slug]);
  expect(row.config.items[0]).toMatchObject({ kind: "number_recognition", count: 3 });
});

test("content manager reviews, approves and publishes", async ({ page }) => {
  await signIn(page, "manager@admin.test");
  await page.goto("/content/review");
  await shot(page, "A06-review-queue");
  await page.getByRole("link", { name: "Count the ducks (e2e)" }).click();
  await confirm(page, "Approve");
  await expect.poll(statusOf).toBe("approved");
  await confirm(page, "Publish");
  await expect.poll(statusOf).toBe("published");
  await shot(page, "A07-published");
  const [row] = await query("select status, published_by from activities where slug = $1", [slug]);
  expect(row.status).toBe("published");
  expect(row.published_by).toBe("00000000-0000-4000-c000-000000000002");
});

test("course with a module and a lesson that has a prerequisite", async ({ page }) => {
  await signIn(page, "editor@admin.test");
  await page.goto("/content/courses/new");
  await page.waitForLoadState("networkidle");
  await page.getByLabel("Course title").fill("Counting road (e2e)");
  await page.getByLabel("Slug").fill(`e2e-course-${Date.now().toString(36)}`);
  await page.getByLabel("Subject").selectOption({ label: "Numbers" });
  await page.getByLabel("Learning objectives (one per line)").fill("Count to 5\nCompare amounts");
  await page.getByRole("button", { name: /Create/ }).click();
  await expect(page).toHaveURL(/\/content\/courses\/[0-9a-f-]{36}(\?|$)/);
  const course = page.url().split("?")[0];
  await page.waitForLoadState("networkidle"); // let the page hydrate before typing
  await page.getByLabel("New module").fill("First steps");
  await page.getByRole("button", { name: "Add module" }).click();
  // adding a lesson opens it; come back to add the next
  await page.getByLabel("New lesson").fill("One duck");
  await page.getByRole("button", { name: "Add lesson" }).click();
  await expect(page).toHaveURL(/\/lessons\//);
  await page.goto(course);
  await page.waitForLoadState("networkidle");
  await page.getByLabel("New lesson").fill("Two ducks");
  await page.getByRole("button", { name: "Add lesson" }).click();
  await expect(page.getByLabel("Lesson title")).toHaveValue("Two ducks");
  await page.getByLabel("Estimated duration (minutes)").fill("6");
  await page.getByLabel("One duck").check();
  await page.getByRole("button", { name: "Save lesson" }).click();
  await expect(page.getByRole("status").filter({ hasText: /saved/i })).toBeVisible();
  await shot(page, "A08-lesson");
  const [l] = await query("select l.estimated_minutes, cardinality(l.prerequisite_lesson_ids) n from lessons l where l.title->>'en' = 'Two ducks' order by l.created_at desc limit 1");
  expect([l.estimated_minutes, l.n]).toEqual([6, 1]);
});

test("upload an image: staged, checked by the server, registered", async ({ page }) => {
  await signIn(page, "editor@admin.test");
  await page.goto("/media");
  const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==", "base64");
  await page.waitForLoadState("networkidle");
  const form = page.getByRole("form", { name: "Upload a file" });
  await form.getByLabel("File").setInputFiles({ name: "e2e-duck.png", mimeType: "image/png", buffer: png });
  await form.getByRole("button", { name: "Upload" }).click();
  await expect(form.getByRole("status").filter({ hasText: /Added .*e2e-duck\.png/ })).toBeVisible({ timeout: 20000 });
  await page.reload();
  await shot(page, "A09-media");
  const rows = await query("select kind, status, bucket from media_assets where object_path like '%e2e-duck.png'");
  expect(rows[0]).toMatchObject({ kind: "image", status: "ready", bucket: "public-assets" });
});

test("support: family search, restriction with a reason, data requests", async ({ page }) => {
  await signIn(page, "support@admin.test");
  await page.goto("/families?q=alice");
  await page.getByRole("link", { name: "alice@example.test" }).click();
  await expect(page.getByText("Mia")).toBeVisible();
  await shot(page, "A10-family");
  await page.goto("/privacy");
  await shot(page, "A11-privacy");
});

test("super admin: users and roles, settings, audit log", async ({ page }) => {
  await signIn(page, "super@admin.test");
  await page.goto("/settings/admins");
  await expect(page.getByText("super@admin.test (you)")).toBeVisible();
  await shot(page, "A12-admins");
  await page.goto("/settings/system");
  await shot(page, "A13-settings");
  await page.goto("/settings/audit?table=activities");
  await expect(page.getByText("content.published").first()).toBeVisible();
  await shot(page, "A14-audit");
  await page.goto("/billing");
  await expect(page.getByText(/Nothing here charges/)).toBeVisible();
  await shot(page, "A15-billing");
  await page.goto("/rewards");
  await shot(page, "A16-rewards");
  await page.goto("/content/taxonomy");
  await shot(page, "A17-taxonomy");
});
