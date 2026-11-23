// Every engine kind played through the real web UI (mouse on desktop, taps on the phone
// project), from content made with the admin game builder (kids_app/test/fixtures/admin_cms).
// Each finished game must be saved as a completed web session through /play/sync.
import { expect, test, type Locator, type Page } from "@playwright/test";
import { chooseChild, childId, ensureGames, signIn, sql, webSessions } from "./helpers";

import { ITEMS, TITLE } from "./helpers";
const ids: Record<string, string> = {};

test.beforeAll(async () => { Object.assign(ids, await ensureGames()); });

let touchMode = false;
test.beforeEach(({}, info) => { touchMode = !!info.project.use.hasTouch; });
const touch = (page: Page) => touchMode && page.viewportSize() !== null;
async function tapOrClick(page: Page, l: Locator) { if (touch(page)) await l.tap(); else await l.click(); }
async function dragTo(page: Page, from: Locator, to: Locator) {
  if (touch(page)) { await from.tap(); await to.tap(); return; } // tap-to-pick, tap-to-place
  const a = (await from.boundingBox())!, b = (await to.boundingBox())!;
  await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2);
  await page.mouse.down();
  await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2, { steps: 12 });
  await page.mouse.up();
}
/** After an answer: "Try again" → retry; "Next"/"Finish" → continue. Returns true when finished. */
async function settle(page: Page) {
  const again = page.getByRole("button", { name: "Try again" });
  const next = page.getByRole("button", { name: /^(Next|Finish)$/ });
  await expect(again.or(next).first()).toBeVisible();
  if (await next.isVisible()) { await tapOrClick(page, next); return true; }
  await tapOrClick(page, again);
  return false;
}

const SOLVE: Record<string, (page: Page) => Promise<void>> = {
  choice: async (page) => {
    const opts = page.getByRole("group", { name: "Answers" }).getByRole("button");
    for (let i = 0; i < (await opts.count()); i++) {
      if (!(await opts.nth(i).isEnabled())) continue;
      await tapOrClick(page, opts.nth(i));
      if (await settle(page)) return;
    }
  },
  place: async (page) => {
    const pieces = page.getByRole("group", { name: "Pieces to place" }).getByRole("button");
    const places = page.getByRole("group", { name: /Places|Board/ }).getByRole("button");
    while ((await pieces.count()) > 0) {
      const piece = pieces.first();
      const label = (await piece.getAttribute("aria-label")) ?? "";
      const left = await pieces.count();
      const jig = /^Piece (\d+)$/.exec(label);
      if (jig) { await dragTo(page, piece, page.getByRole("button", { name: `Space ${jig[1]}`, exact: true })); continue; }
      for (let t = 0; t < (await places.count()); t++) {
        await dragTo(page, piece, places.nth(t));
        await page.waitForTimeout(80);
        if ((await pieces.count()) < left) break;
      }
    }
    await settle(page);
  },
  word_build: async (page) => {
    for (const ch of "cat") await tapOrClick(page, page.getByRole("group", { name: "Letters" }).getByRole("button", { name: ch, exact: true }).first());
    await settle(page);
  },
  puzzle: async (page) => {
    const tiles = page.locator("[data-piece]");
    const n = await tiles.count();
    for (let i = 0; i < n; i++) {
      const order = await tiles.evaluateAll((els) => els.map((e) => e.getAttribute("data-piece")));
      if (order[i] === `p${i}`) continue;
      await tapOrClick(page, page.locator(`[data-piece="p${i}"]`));
      await tapOrClick(page, page.locator(`[data-piece="${order[i]}"]`));
      if (await page.getByRole("button", { name: /^(Next|Finish)$/ }).isVisible()) break;
    }
    await settle(page);
  },
  memory: async (page) => {
    const cards = page.getByRole("group", { name: "Cards" }).getByRole("button");
    const n = await cards.count();
    const face: string[] = [];
    const faceOf = async (i: number) => ((await cards.nth(i).getAttribute("aria-label")) ?? "").replace(/^Card \d+: /, "");
    for (let i = 0; i < n; i += 2) { // look at every card once, two at a time
      await tapOrClick(page, cards.nth(i)); face[i] = await faceOf(i);
      await tapOrClick(page, cards.nth(i + 1)); face[i + 1] = await faceOf(i + 1);
      await page.waitForTimeout(1000);
    }
    const done = new Set<number>();
    for (let i = 0; i < n; i++) {
      if (done.has(i) || !(await cards.nth(i).isEnabled())) continue;
      const j = face.findIndex((f, k) => k !== i && f === face[i] && !done.has(k));
      await tapOrClick(page, cards.nth(i)); await tapOrClick(page, cards.nth(j));
      done.add(i); done.add(j);
      await page.waitForTimeout(450);
    }
    await settle(page);
  },
  trace: async (page) => {
    const svg = page.getByRole("img", { name: /Trace/ });
    const box = (await svg.boundingBox())!;
    const strokes = await svg.locator("polyline[stroke-width='12']").evaluateAll((els) => els.map((e) => e.getAttribute("points") ?? ""));
    for (const s of strokes) {
      const pts = s.trim().split(/\s+/).map((p) => p.split(",").map(Number));
      const at = ([x, y]: number[]) => [box.x + (x / 100) * box.width, box.y + (y / 100) * box.height];
      const [x0, y0] = at(pts[0]);
      await page.mouse.move(x0, y0); await page.mouse.down();
      for (const p of pts.slice(1)) { const [x, y] = at(p); await page.mouse.move(x, y, { steps: 4 }); }
      await page.mouse.up();
    }
    await page.getByRole("button", { name: "Done" }).click();
    while (!(await settle(page))) { /* if a stroke missed, the engine allows more tries and then shows it */
      if (await page.getByRole("button", { name: "Done" }).isEnabled().catch(() => false)) await page.getByRole("button", { name: "Done" }).click();
    }
  },
};
const solver = (kind: string) =>
  ["match_pairs", "sort", "drag_to_target", "jigsaw"].includes(kind) ? SOLVE.place : SOLVE[kind] ?? SOLVE.choice;

for (const it of ITEMS) {
  const tags = it.kind === "trace" ? "" : " @touch";
  test(`${TITLE[it.kind]} (${it.kind}) is played to the end and saved${tags}`, async ({ page }) => {
    await signIn(page);
    await chooseChild(page, "Mia");
    await page.goto(`/kids/play/${ids[it.kind]}`);
    await page.getByRole("button", { name: "Play" }).click();
    await solver(it.kind)(page);
    await expect(page.getByRole("heading", { name: "All done!" })).toBeVisible();
    await expect(page.getByText(/You earned|Saved\./)).toBeVisible();
    const s = await webSessions(await childId("Mia"), ids[it.kind]);
    expect(s[0]).toMatchObject({ status: "completed", platform: "web" });
    expect((s[0].metrics as { items: { k: string }[] }).items[0].k).toBe(it.kind);
  });
}

test("leaving mid-game is saved as stopped early, and the quiz from the seed records responses", async ({ page }) => {
  await signIn(page);
  await chooseChild(page, "Mia");
  await page.goto(`/kids/play/${ids.multiple_choice}`);
  await page.getByRole("button", { name: "Play" }).click();
  await page.getByRole("link", { name: "Stop" }).click();
  await expect.poll(async () => (await webSessions(await childId("Mia"), ids.multiple_choice))[0]?.status).toBe("abandoned");
  const [quiz] = await sql<{ id: string }>("select id from activities where slug = 'letters-check'");
  await page.goto(`/kids/play/${quiz.id}`);
  await page.getByRole("button", { name: "Play" }).click();
  while (!(await page.getByRole("heading", { name: "All done!" }).isVisible())) await SOLVE.choice(page);
  await expect.poll(async () => (await sql("select count(*)::int n from question_responses qr join activity_sessions s on s.id = qr.session_id where s.activity_id = $1 and s.platform = 'web'", [quiz.id]))[0].n).toBeGreaterThan(0);
});
