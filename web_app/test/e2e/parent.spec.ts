// The grown-up area: the gate, the family overview, reports, goals, controls, notifications,
// children, privacy and subscription — the same Edge Functions and tables as the app.
import { expect, test } from "@playwright/test";
import { chooseChild, childId, passGate, signIn, sql } from "./helpers";

test("the parental gate: a wrong answer stays out; the kid zone locks it again", async ({ page }) => {
  await signIn(page);
  await chooseChild(page, "Mia");
  await page.getByRole("link", { name: "Grown-ups" }).click();
  await expect(page).toHaveURL(/\/gate/);
  await page.getByLabel(/What is/).fill("1");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByRole("alert").filter({ hasText: "Not quite" })).toBeVisible();
  await passGate(page);
  await expect(page.getByRole("heading", { name: "Your family" })).toBeVisible();
  await page.getByRole("button", { name: "Back to playing" }).first().click();
  await expect(page).toHaveURL(/\/who/);
  await page.goto("/parents");
  await expect(page).toHaveURL(/\/gate/);
});

test("overview and reports: both children; day, week and month; charts with tables", async ({ page }) => {
  await signIn(page);
  await passGate(page);
  await expect(page.getByRole("heading", { name: "Mia" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Leo" })).toBeVisible();
  await page.getByRole("link", { name: "Progress report" }).first().click();
  await expect(page.getByRole("heading", { name: "Mia's progress" })).toBeVisible();
  for (const p of ["Day", "Week", "Month"]) {
    await page.getByRole("navigation", { name: "Period" }).getByRole("link", { name: p }).click();
    await expect(page.getByRole("navigation", { name: "Period" }).getByRole("link", { name: p })).toHaveAttribute("aria-current", "page");
  }
  await page.getByRole("navigation", { name: "Period" }).getByRole("link", { name: "Week" }).click();
  await expect(page.getByRole("figure", { name: "Learning time" })).toBeVisible();
  await page.getByRole("figure", { name: "Subjects" }).getByText("Show as a table").click();
  await expect(page.getByRole("figure", { name: "Subjects" }).getByRole("table")).toBeVisible();
  await page.getByRole("navigation", { name: "Child" }).getByRole("link", { name: "Leo" }).click();
  await expect(page.getByRole("heading", { name: "Leo's progress" })).toBeVisible();
  await page.getByRole("link", { name: "← Earlier" }).click();
  await page.getByRole("link", { name: "← Earlier" }).click();
  await expect(page.getByText(/No activity in this week/)).toBeVisible();
});

test("goals and controls are saved through the server and change what the child gets", async ({ page }) => {
  const leo = await childId("Leo");
  await signIn(page);
  await passGate(page, `/parents/children/${leo}/rewards`);
  await page.getByLabel("Activities a day").fill("5");
  await page.getByRole("button", { name: "Save goals" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Goals saved" })).toBeVisible();
  expect((await sql("select daily_activities from learning_goals where child_id = $1", [leo]))[0].daily_activities).toBe(5);
  await page.goto(`/parents/children/${leo}/controls`);
  await page.locator("input[name=listen]").uncheck();
  await page.getByLabel("Time per day").selectOption("30");
  await page.getByRole("button", { name: "Save controls" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Saved" })).toBeVisible();
  expect((await sql("select listen_enabled, daily_limit_minutes from screen_time_rules where child_id = $1", [leo]))[0]).toEqual({ listen_enabled: false, daily_limit_minutes: 30 });
  await chooseChild(page, "Leo");
  await expect(page.getByRole("navigation", { name: "Sections" }).getByRole("link", { name: "Listen" })).toHaveCount(0);
  await passGate(page, `/parents/children/${leo}/controls`);
  await page.locator("input[name=listen]").check();
  await page.getByLabel("Time per day").selectOption("");
  await page.getByRole("button", { name: "Save controls" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Saved" })).toBeVisible();
});

test("children: add, rename; notifications; export; subscription", async ({ page }) => {
  await signIn(page);
  await passGate(page, "/parents/children/new");
  await page.getByLabel("First name or nickname").fill("Noor");
  await page.getByLabel("Month and year of birth").fill("2020-09");
  await page.getByRole("button", { name: "Add child" }).click();
  await expect(page.getByText("Noor is ready to play.")).toBeVisible();
  await page.getByLabel("First name or nickname").fill("Noora");
  await page.getByRole("button", { name: "Save" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Saved" })).toBeVisible();
  expect((await sql("select count(*)::int n from child_profiles where nickname = 'Noora'"))[0].n).toBe(1);

  await page.goto("/parents/notifications");
  await page.getByLabel("Weekly learning summary").uncheck();
  await page.getByRole("button", { name: "Save" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Preferences saved" })).toBeVisible();
  expect((await sql("select enabled from notification_preferences np join auth.users u on u.id = np.user_id where u.email = 'alice@example.test' and type = 'weekly_progress' and channel = 'in_app'"))[0].enabled).toBe(false);

  await page.goto("/parents/privacy");
  await expect(page.getByRole("table").first()).toContainText("Collecting your child's learning progress");
  await page.getByRole("button", { name: "Make an export" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Your export is ready" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Download" }).first()).toBeVisible();

  await page.goto("/parents/subscription");
  await expect(page.getByText("Plus works until")).toBeVisible();
  await expect(page.getByText(/Buying on the web isn't connected yet/)).toBeVisible();
});
