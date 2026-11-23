// Video, songs and illustrated stories: playback, the server's launch gate, resume (continue
// watching / listening / reading) and completion — saved as web sessions.
import { expect, test, type Page } from "@playwright/test";
import { chooseChild, childId, signIn, sql, webSessions } from "./helpers";

const firstMedia = async (page: Page, list: string, prefix: string) => {
  await page.goto(list);
  const href = await page.locator(`main a[href^='${prefix}']`).first().getAttribute("href");
  return href!.split("/").pop()!;
};

test("video: plays, leaving saves the place, 'Keep watching' resumes there, finishing saves it", async ({ page }) => {
  await signIn(page);
  await chooseChild(page, "Mia");
  const id = await firstMedia(page, "/kids/watch", "/kids/watch/");
  await page.goto(`/kids/watch/${id}`);
  const video = page.locator("video");
  await expect(video).toHaveAttribute("src", /\/storage\/v1\/object\/sign\/video\/.+\.mp4\?token=/); // short-lived URL from play/launch
  await page.getByRole("button", { name: "Play" }).first().click();
  await expect.poll(() => video.evaluate((v: HTMLVideoElement) => v.currentTime), { timeout: 20000 }).toBeGreaterThan(5.5);
  await page.getByRole("button", { name: "Pause" }).click();
  await page.getByRole("link", { name: "Watch" }).first().click();
  const mia = await childId("Mia");
  await expect.poll(async () => (await webSessions(mia, id))[0]?.status).toBe("abandoned");
  expect(Number((await webSessions(mia, id))[0].metrics?.positionMs)).toBeGreaterThan(5000);
  await page.reload();
  await expect(page.getByRole("region", { name: "Keep watching" })).toBeVisible();
  await page.getByRole("region", { name: "Keep watching" }).getByRole("link").first().click();
  await expect(page.getByText(/Carrying on from 0:0[5-9]/)).toBeVisible();
  await page.getByRole("button", { name: "Play" }).first().click();
  await expect.poll(() => video.evaluate((v: HTMLVideoElement) => v.currentTime)).toBeGreaterThan(5);
  await video.evaluate((v: HTMLVideoElement) => { v.currentTime = v.duration - 0.5; });
  await expect(page.getByRole("dialog", { name: "Well done!" })).toBeVisible({ timeout: 20000 });
  await expect.poll(async () => (await webSessions(mia, id))[0]?.status).toBe("completed");
});

test("song: plays and resumes from where it stopped", async ({ page }) => {
  await signIn(page);
  await chooseChild(page, "Mia");
  const id = await firstMedia(page, "/kids/listen", "/kids/listen/songs/");
  await page.goto(`/kids/listen/songs/${id}`);
  await page.getByRole("button", { name: "Play" }).click();
  const audio = page.locator("audio");
  await expect.poll(() => audio.evaluate((a: HTMLAudioElement) => a.currentTime), { timeout: 20000 }).toBeGreaterThan(5.5);
  await page.getByRole("button", { name: "Pause" }).click();
  await page.goto("/kids/listen");
  await expect.poll(async () => (await webSessions(await childId("Mia"), id))[0]?.status).toBe("abandoned");
  await page.goto(`/kids/listen/songs/${id}`);
  await expect(page.getByText(/Carrying on from 0:0[5-9]/)).toBeVisible();
});

test("illustrated story: turn pages (buttons and keys), stop on page 2, come back there, read to the end @touch", async ({ page }) => {
  await signIn(page);
  await chooseChild(page, "Mia");
  const id = await firstMedia(page, "/kids/listen", "/kids/listen/stories/");
  await page.goto(`/kids/listen/stories/${id}`);
  await expect(page.getByText(/Page 1 of \d+/)).toBeVisible();
  await page.getByRole("button", { name: "Next page" }).click();
  await expect(page.getByText(/Page 2 of/)).toBeVisible();
  await page.goto("/kids/listen");
  const mia = await childId("Mia");
  await expect.poll(async () => (await webSessions(mia, id))[0]?.metrics?.page).toBe(1);
  await page.goto(`/kids/listen/stories/${id}`);
  await expect(page.getByText("You were on page 2.")).toBeVisible();
  const total = Number((await page.getByText(/Page \d+ of \d+/).innerText()).match(/of (\d+)/)![1]);
  for (let i = 2; i < total; i++) await page.keyboard.press("ArrowRight");
  await page.getByRole("button", { name: "The end" }).click();
  await expect(page.getByRole("dialog", { name: "Well done!" })).toBeVisible();
  await expect.poll(async () => (await webSessions(mia, id))[0]?.status).toBe("completed");
});

test("a grown-up's switches are enforced by the server, not just hidden", async ({ page }) => {
  const mia = await childId("Mia");
  await sql("insert into screen_time_rules (child_id, watch_enabled) values ($1, false) on conflict (child_id) do update set watch_enabled = false", [mia]);
  try {
    await signIn(page);
    await chooseChild(page, "Mia");
    await expect(page.getByRole("navigation", { name: "Sections" }).getByRole("link", { name: "Watch" })).toHaveCount(0);
    const [v] = await sql<{ id: string }>("select id from activities where type = 'video' and status = 'published' limit 1");
    await page.goto(`/kids/watch/${v.id}`);
    await expect(page.getByText("A grown-up switched this off.")).toBeVisible(); // play/launch said SECTION_DISABLED
    await expect(page.locator("video")).toHaveCount(0);
  } finally {
    await sql("update screen_time_rules set watch_enabled = true where child_id = $1", [mia]);
  }
});
