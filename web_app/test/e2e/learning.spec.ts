// Child profile selection, browsing (subjects, categories, paths, courses), lesson navigation,
// progress indicators and prerequisites — with progress saved by the web player.
import { expect, test } from "@playwright/test";
import { chooseChild, ensureCourse, signIn, sql } from "./helpers";

test("choose a child, browse subjects and categories, follow a course lesson by lesson @touch", async ({ page }) => {
  const c = await ensureCourse();
  // a clean start on the test course (other device projects run this too, on the same data)
  const mia = (await sql<{ id: string }>("select id from child_profiles where nickname = 'Mia'"))[0].id;
  await sql("delete from lesson_step_completions where child_id = $1 and step_id in (select s.id from lesson_steps s join lessons l on l.id = s.lesson_id join course_modules m on m.id = l.module_id where m.course_id = $2)", [mia, c.course]);
  await sql("delete from course_enrollments where child_id = $1 and course_id = $2", [mia, c.course]);
  await signIn(page);
  await expect(page.getByRole("heading", { name: "Who's playing?" })).toBeVisible();
  await chooseChild(page, "Mia");
  await expect(page.getByRole("navigation", { name: "Sections" }).getByRole("link")).toHaveCount(6);

  await page.goto("/kids/subjects");
  await page.getByRole("link", { name: /^Numbers/ }).click();
  await expect(page.getByRole("heading", { name: "Numbers", level: 1 })).toBeVisible();
  await expect(page.getByRole("region", { name: "Games" }).getByRole("link").first()).toBeVisible();

  await page.goto("/kids/learn");
  await page.getByRole("link", { name: /Counting together/ }).click();
  await expect(page).toHaveURL(new RegExp(c.course));
  const lessons = page.getByRole("list", { name: "Lessons" }).getByRole("listitem");
  await expect(lessons.nth(0)).toHaveAccessibleName(/First steps, (ready|started)/);
  await expect(lessons.nth(1)).toHaveAccessibleName(/Next steps, locked/);
  await expect(page.getByRole("progressbar", { name: "Course progress" })).toHaveAttribute("aria-valuenow", "0");

  await lessons.nth(0).getByRole("link").click();
  await page.getByRole("link", { name: /Quiz game/ }).click();
  await expect(page).toHaveURL(/step=/);
  await page.getByRole("button", { name: "Play" }).click();
  const opts = page.getByRole("group", { name: "Answers" }).getByRole("button");
  for (let i = 0; i < (await opts.count()); i++) {
    await opts.nth(i).click();
    const next = page.getByRole("button", { name: /^(Next|Finish)$/ });
    await expect(next.or(page.getByRole("button", { name: "Try again" })).first()).toBeVisible();
    if (await next.isVisible()) { await next.click(); break; }
    await page.getByRole("button", { name: "Try again" }).click();
  }
  await expect(page.getByRole("heading", { name: "All done!" })).toBeVisible();
  await page.getByRole("link", { name: "Back to the lesson" }).click();
  await expect(page.getByRole("link", { name: "Next lesson: Next steps" })).toBeVisible();
  await page.goto(`/kids/courses/${c.course}`);
  await expect(page.getByRole("list", { name: "Lessons" }).getByRole("listitem").nth(0)).toHaveAccessibleName(/First steps, done/);
  await expect(page.getByRole("list", { name: "Lessons" }).getByRole("listitem").nth(1)).toHaveAccessibleName(/Next steps, ready/);
  await expect(page.getByRole("progressbar", { name: "Course progress" })).toHaveAttribute("aria-valuenow", "50");
});

test("a locked lesson can't be opened by its address", async ({ page }) => {
  await signIn(page);
  await chooseChild(page, "Leo");
  const c = await ensureCourse();
  await page.goto(`/kids/courses/${c.course}/lessons/${c.l2}`);
  await expect(page).toHaveURL(new RegExp(`/kids/courses/${c.course}$`));
});

test("Me: change buddy; rewards page shows stars, goals and badges", async ({ page }) => {
  await signIn(page);
  await chooseChild(page, "Leo");
  await page.goto("/kids/me");
  await page.getByRole("radio", { name: "Sprout" }).check({ force: true });
  await page.getByRole("button", { name: "Choose this buddy" }).click();
  await expect(page.getByRole("radio", { name: "Sprout" })).toBeChecked();
  await page.getByRole("link", { name: /My stars and badges/ }).click();
  await expect(page.getByRole("heading", { name: /Badges \(\d+ of \d+\)/ })).toBeVisible();
});
