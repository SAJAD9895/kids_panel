import { expect, type Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import pg from "pg";

export const PASSWORD = "Parent-pass-123";
export const ALICE = "alice@example.test";
export const BOB = "bob@example.test";
const stack = () => JSON.parse(readFileSync("test/e2e/.stack.json", "utf8")) as { dbUrl: string; url: string; anonKey: string };

/** Direct database access as the owner (checking results only). */
export async function sql<T = Record<string, unknown>>(q: string, params: unknown[] = []): Promise<T[]> {
  const c = new pg.Client({ connectionString: stack().dbUrl });
  await c.connect();
  try { return (await c.query(q, params)).rows as T[]; } finally { await c.end(); }
}
/** The last code the stack "mailed" to an address. */
export async function mailedCode(email: string, kind: "code" | "recovery" = "code"): Promise<string> {
  for (let i = 0; i < 40; i++) {
    const r = (await (await fetch(`http://localhost:3211/?email=${encodeURIComponent(email)}`)).json()) as { code?: string; recovery?: string };
    if (r[kind]) return r[kind]!;
    await new Promise((ok) => setTimeout(ok, 150));
  }
  throw new Error(`no ${kind} mailed to ${email}`);
}
/** A parent's access token straight from the stack (for API-level checks). */
export async function tokenFor(email: string) {
  const s = stack();
  const r = await (await fetch(`${s.url}/auth/v1/token?grant_type=password`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, password: PASSWORD }) })).json();
  return { token: r.access_token as string, url: s.url, anonKey: s.anonKey };
}

export async function signIn(page: Page, email = ALICE, password = PASSWORD) {
  await page.goto("/sign-in");
  await page.getByLabel("Email").first().fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/\/who|\/parents|\/kids/);
}
export async function chooseChild(page: Page, name: string) {
  await page.goto("/who");
  await page.getByRole("button", { name: new RegExp(`^${name}$`) }).click();
  await expect(page).toHaveURL(/\/kids$/);
  await expect(page.getByRole("heading", { name: `Hi ${name}!` })).toBeVisible();
}
const WORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"];
export async function passGate(page: Page, next = "/parents") {
  await page.goto(`/gate?next=${encodeURIComponent(next)}`);
  await page.waitForLoadState("networkidle");
  const q = await page.locator("label[for=gate-answer]").innerText();
  const [a, b] = [...q.matchAll(/\b(three|four|five|six|seven|eight|nine)\b/g)].map((m) => WORDS.indexOf(m[1]));
  await page.getByLabel(/What is/).fill(String(a * b));
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(new RegExp(next.replace(/[/?]/g, (c) => `\\${c}`)));
}
export async function childId(nickname: string) {
  return (await sql<{ id: string }>("select id from child_profiles where nickname = $1", [nickname]))[0].id;
}
/** Sessions this child sent from the web for an activity. */
export const webSessions = (child: string, activity: string) =>
  sql<{ status: string; platform: string; score: number | null; metrics: Record<string, unknown> | null }>(
    `select s.status, s.platform, r.score, r.metrics from activity_sessions s left join activity_results r on r.session_id = s.id
     where s.child_id = $1 and s.activity_id = $2 order by s.started_at desc`, [child, activity]);
export async function shot(page: Page, name: string) {
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: `../docs/web/screens/${name}.png`, fullPage: true });
}

// ---- test content: one published game per engine kind (from the admin builder's fixture) and a
// two-lesson course whose second lesson needs the first.
type Item = Record<string, unknown> & { kind: string };
const fixture = JSON.parse(readFileSync("../kids_app/test/fixtures/admin_cms/every_kind.json", "utf8")) as { levels: { items: Item[] }[] };
// (word_build: the builder writes `extra` as a list, which both apps read as text; see the testing report)
export const ITEMS = fixture.levels.flatMap((l) => l.items).map((it) => (it.kind === "word_build" ? { ...it, extra: "xz" } : it));
export const TITLE: Record<string, string> = {
  multiple_choice: "Quiz game", image_choice: "Picture matching", audio_choice: "Listen and choose", fill_blank: "Fill the gap", word_build: "Word building",
  letter_recognition: "Alphabet game", trace: "Tracing", number_recognition: "Counting game", arithmetic: "Number sums", match_pairs: "Matching pairs",
  memory: "Memory", sort: "Sorting", drag_to_target: "Drag and drop", puzzle: "Picture puzzle", jigsaw: "Jigsaw", shape_complete: "Finish the shape",
};
export async function ensureGames(): Promise<Record<string, string>> {
  const ids: Record<string, string> = {};
  const [{ subj }] = await sql<{ subj: string }>("select id subj from subjects where key = 'numbers'");
  const [{ tmpl }] = await sql<{ tmpl: string }>("select id tmpl from game_templates where key = 'learning_engine' order by version desc limit 1");
  for (const it of ITEMS) {
    const slug = `web-e2e-${it.kind.replace(/_/g, "-")}`;
    const [row] = await sql<{ id: string }>(
      `insert into activities (slug, type, title, subject_id, age_min_months, age_max_months, difficulty, status, published_at)
       values ($1, 'game', jsonb_build_object('en', $2::text), $3, 12, 144, 1, 'published', now())
       on conflict (slug) do update set status = 'published' returning id`, [slug, TITLE[it.kind], subj]);
    await sql("insert into games (activity_id, template_id, config) values ($1, $2, $3) on conflict (activity_id) do update set config = excluded.config",
      [row.id, tmpl, JSON.stringify({ items: [it] })]);
    ids[it.kind] = row.id;
  }
  return ids;
}
export async function ensureCourse(): Promise<{ course: string; l1: string; l2: string; step1: string }> {
  const ids = await ensureGames();
  const have = await sql<{ id: string }>("select id from courses where slug = 'web-e2e-course'");
  if (have[0]) {
    const ls = await sql<{ id: string; position: number }>("select l.id, l.position from lessons l join course_modules m on m.id = l.module_id where m.course_id = $1 order by l.position", [have[0].id]);
    const [st] = await sql<{ id: string }>("select id from lesson_steps where lesson_id = $1", [ls[0].id]);
    return { course: have[0].id, l1: ls[0].id, l2: ls[1].id, step1: st.id };
  }
  const [{ subj }] = await sql<{ subj: string }>("select id subj from subjects where key = 'numbers'");
  const [c] = await sql<{ id: string }>(`insert into courses (slug, title, description, stage, subject_id, status, sort, published_at)
    values ('web-e2e-course', '{"en":"Counting together"}', '{"en":"Two short lessons"}', 'preschool', $1, 'published', 0, now()) returning id`, [subj]);
  const [m] = await sql<{ id: string }>(`insert into course_modules (course_id, position, title) values ($1, 0, '{"en":"Start"}') returning id`, [c.id]);
  const [l1] = await sql<{ id: string }>(`insert into lessons (module_id, position, title) values ($1, 0, '{"en":"First steps"}') returning id`, [m.id]);
  const [l2] = await sql<{ id: string }>(`insert into lessons (module_id, position, title, prerequisite_lesson_ids) values ($1, 1, '{"en":"Next steps"}', array[$2::uuid]) returning id`, [m.id, l1.id]);
  const [s1] = await sql<{ id: string }>(`insert into lesson_steps (lesson_id, position, step_type, activity_id, required) values ($1, 0, 'practice', $2, true) returning id`, [l1.id, ids.multiple_choice]);
  await sql(`insert into lesson_steps (lesson_id, position, step_type, activity_id, required) values ($1, 0, 'practice', $2, true)`, [l2.id, ids.arithmetic]);
  return { course: c.id, l1: l1.id, l2: l2.id, step1: s1.id };
}
