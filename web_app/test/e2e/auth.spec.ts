import { expect, test } from "@playwright/test";
import { ALICE, BOB, mailedCode, PASSWORD, signIn, sql } from "./helpers";

test.describe.configure({ mode: "serial" });
const NEW = `parent-${Date.now().toString(36)}@example.test`;

test("signed out: the child zone and grown-up pages send you to sign-in", async ({ page }) => {
  for (const p of ["/who", "/kids", "/kids/games", "/parents", "/parents/children"]) {
    await page.goto(p);
    await expect(page, p).toHaveURL(/\/sign-in\?next=/);
  }
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Play, learn and grow" })).toBeVisible();
});

test("registration: email code → family and consents → optional password → who's playing", async ({ page }) => {
  await page.goto("/sign-up");
  await page.getByLabel("Your email (a grown-up's)").fill(NEW);
  await page.getByRole("button", { name: "Send me a code" }).click();
  await expect(page).toHaveURL(/\/sign-up\/verify/);
  await page.getByLabel("6-digit code").fill("000000");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByRole("alert").filter({ hasText: /wrong or has expired/ })).toBeVisible();
  await page.getByLabel("6-digit code").fill(await mailedCode(NEW));
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/sign-up\/family/);
  await page.waitForLoadState("networkidle");
  await page.getByLabel("Child's first name or nickname").fill("Ada");
  await page.getByLabel("Month and year of birth").fill("2021-03");
  await page.getByRole("button", { name: "Create our family" }).click();
  await expect(page.getByRole("alert").filter({ hasText: /Check the highlighted fields/ })).toBeVisible(); // consents missing
  await page.getByLabel("I accept the terms of use").check();
  await page.getByLabel("I've read the privacy policy").check();
  await page.getByLabel(/I consent to saving my child's learning progress/).check();
  await page.getByRole("button", { name: "Create our family" }).click();
  await expect(page).toHaveURL(/\/sign-up\/password/);
  const [acc] = await sql<{ n: number; c: number; tz: string }>(
    `select (select count(*) from parental_consents pc where pc.account_id = a.id)::int n, (select count(*) from child_profiles c where c.account_id = a.id)::int c, a.timezone tz
     from parent_accounts a join auth.users u on u.id = a.owner_user_id where u.email = $1`, [NEW]);
  expect(acc).toMatchObject({ n: 3, c: 1 });
  await page.getByLabel("Password", { exact: true }).fill("weak");
  await page.getByLabel("The same password again").fill("weak");
  await page.getByRole("button", { name: "Save password" }).click();
  await expect(page.getByRole("alert").filter({ hasText: "At least 10 characters" })).toBeVisible();
  await page.getByLabel("Password", { exact: true }).fill("New-family-pass-1");
  await page.getByLabel("The same password again").fill("New-family-pass-1");
  await page.getByRole("button", { name: "Save password" }).click();
  await expect(page).toHaveURL(/\/who/);
  await expect(page.getByRole("button", { name: "Ada" })).toBeVisible();
});

test("sign-in: wrong password, then right; session persists; sign-out ends it", async ({ page }) => {
  await page.goto("/sign-in");
  await page.getByLabel("Email").first().fill(ALICE);
  await page.getByLabel("Password").fill("Wrong-password-1");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByRole("alert").filter({ hasText: "don't match" })).toBeVisible();
  await signIn(page);
  await page.reload();
  await expect(page).toHaveURL(/\/who/); // still signed in after a reload (cookie session)
  await page.goto("/parents/settings");
  await page.getByRole("button", { name: "Sign out" }).last().click();
  await expect(page).toHaveURL(/\/sign-in\?signedOut=1/);
  await page.goto("/kids");
  await expect(page).toHaveURL(/\/sign-in/);
});

test("sign-in with an emailed code instead of a password", async ({ page }) => {
  await page.goto("/sign-in");
  await page.getByText("No password? Get a code by email").click();
  await page.getByRole("group").or(page.locator("details")).getByLabel("Email").fill(BOB);
  await page.getByRole("button", { name: "Email me a code" }).click();
  await expect(page).toHaveURL(/\/sign-in\/code/);
  await page.getByLabel("6-digit code").fill(await mailedCode(BOB));
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page).toHaveURL(/\/who/);
  await expect(page.getByRole("button", { name: "Sam" })).toBeVisible();
});

test("password recovery: code by email, new password, then sign in with it", async ({ page }) => {
  await page.goto("/forgot-password");
  await page.getByLabel("Email").fill(NEW);
  await page.getByRole("button", { name: "Send a code" }).click();
  await expect(page).toHaveURL(/\/forgot-password\/verify/);
  await page.getByLabel("6-digit code").fill(await mailedCode(NEW, "recovery"));
  await page.getByLabel("New password").fill("Recovered-pass-2");
  await page.getByRole("button", { name: "Save and sign in" }).click();
  await expect(page).toHaveURL(/\/who/);
  await page.context().clearCookies();
  await signIn(page, NEW, "Recovered-pass-2");
  await page.context().clearCookies();
  await page.goto("/sign-in");
  await page.getByLabel("Email").first().fill(NEW);
  await page.getByLabel("Password").fill("New-family-pass-1");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByRole("alert").filter({ hasText: "don't match" })).toBeVisible(); // the old one no longer works
  void PASSWORD;
});
