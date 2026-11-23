// Every major screen at desktop (1440), laptop (1280), tablet (820, touch) and phone (Pixel 7):
// no sideways scrolling, the right navigation for the size, and a screenshot for docs/web/screens.
import { expect, test, type Page } from "@playwright/test";
import { chooseChild, childId, ensureGames, passGate, shot, signIn } from "./helpers";

const noSideScroll = async (page: Page) =>
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(1);

test("layouts @responsive", async ({ page }, info) => {
  const v = info.project.name;
  const games = await ensureGames();
  await signIn(page);
  await shot(page, `W01-who-${v}`); await noSideScroll(page);
  await chooseChild(page, "Mia");
  const rail = page.getByRole("navigation", { name: "Sections" });
  const box = (await rail.boundingBox())!;
  if (v === "desktop" || v === "laptop") expect(box.height).toBeGreaterThan(box.width); // a rail on the left
  else expect(box.width).toBeGreaterThan(box.height); // a bar along the bottom
  for (const [name, path] of [["W02-home", "/kids"], ["W03-learn", "/kids/learn"], ["W04-games", "/kids/games"], ["W05-listen", "/kids/listen"]] as const) {
    await page.goto(path); await page.waitForLoadState("networkidle");
    await shot(page, `${name}-${v}`); await noSideScroll(page);
  }
  await page.goto(`/kids/play/${games.sort}`);
  await page.getByRole("button", { name: "Play" }).click();
  await shot(page, `W06-game-sort-${v}`); await noSideScroll(page);
  await page.goto(`/kids/play/${games.memory}`);
  await page.getByRole("button", { name: "Play" }).click();
  await shot(page, `W07-game-memory-${v}`); await noSideScroll(page);
  await page.goto("/kids/watch");
  await page.locator("main a[href^='/kids/watch/']").first().click();
  await expect(page.locator("video")).toBeVisible();
  await shot(page, `W08-video-${v}`); await noSideScroll(page);
  await page.goto("/kids/listen");
  await page.locator("main a[href^='/kids/listen/stories/']").first().click();
  await expect(page.getByText(/Page 1 of/)).toBeVisible();
  await shot(page, `W09-story-${v}`); await noSideScroll(page);
  await passGate(page);
  await shot(page, `W10-parents-${v}`); await noSideScroll(page);
  await page.goto(`/parents/children/${await childId("Mia")}/report?period=week`);
  await expect(page.getByRole("figure", { name: "Learning time" })).toBeVisible();
  await shot(page, `W11-report-${v}`); await noSideScroll(page);
  await page.goto(`/parents/children/${await childId("Mia")}/controls`);
  await shot(page, `W12-controls-${v}`); await noSideScroll(page);
});

test("keyboard only: sign in, choose a child, open the grown-up area and a report", async ({ page }) => {
  await page.goto("/sign-in");
  await page.keyboard.press("Tab"); // the app name link
  await page.keyboard.press("Tab"); await page.keyboard.type("alice@example.test");
  await page.keyboard.press("Tab"); await page.keyboard.type("Parent-pass-123");
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/\/who/);
  await page.getByRole("button", { name: "Mia" }).focus();
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/\/kids$/);
  await page.getByRole("link", { name: "Grown-ups" }).focus();
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/\/gate/);
  await page.waitForLoadState("networkidle");
  const q = await page.locator("label[for=gate-answer]").innerText();
  const W = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
  const [a, b] = [...q.matchAll(/\b(three|four|five|six|seven|eight|nine)\b/g)].map((m) => W.indexOf(m[1]));
  await page.getByLabel(/What is/).focus();
  await page.keyboard.type(String(a * b));
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/\/parents$/);
  await page.getByRole("link", { name: "Progress report" }).first().focus();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("heading", { name: /progress$/ })).toBeVisible();
  // the focus ring shows on whatever the keyboard focuses
  await page.keyboard.press("Tab");
  const outline = await page.evaluate(() => getComputedStyle(document.activeElement!).outlineStyle);
  expect(outline).not.toBe("none");
});
