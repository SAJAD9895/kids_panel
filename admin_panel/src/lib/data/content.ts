// Content: subjects, categories, courses → modules → lessons → steps, activities, workflow.
// Writes go to the tables as the admin; RLS (content.write), the live-content guard
// (content.publish for anything published or approved) and the audit triggers apply.
import { must, mustOne } from "../errors";
import { z } from "zod";
import type { activityInput, categoryInput, courseInput, lessonInput, subjectInput, Status } from "../validation";
import { type Db, en, like, type Page, PAGE_SIZE, range, withEn, type Row } from "./db";

type In<T extends z.ZodTypeAny> = z.output<T>;

// ---------------------------------------------------------------- subjects
export type Subject = { id: string; key: string; name: string; sort: number; activities: number };
export async function listSubjects(db: Db): Promise<Subject[]> {
  const rows = must(await db.from("subjects").select("id, key, name, sort, activities(count)").order("sort"));
  return rows.map((r: Row) => ({ id: r.id, key: r.key, name: en(r.name), sort: r.sort, activities: r.activities?.[0]?.count ?? 0 }));
}
export async function saveSubject(db: Db, v: In<typeof subjectInput>, id?: string) {
  const row = { key: v.key, sort: v.sort };
  if (id) {
    const old = must(await db.from("subjects").select("name").eq("id", id).single());
    return must(await db.from("subjects").update({ ...row, name: withEn(old.name, v.name) }).eq("id", id).select("id").single());
  }
  return must(await db.from("subjects").insert({ ...row, name: { en: v.name } }).select("id").single());
}
export async function deleteSubject(db: Db, id: string) {
  mustOne(await db.from("subjects").delete().eq("id", id).select("id"));
}

// ---------------------------------------------------------------- categories (with sub-categories)
export type Category = {
  id: string; key: string; name: string; sort: number; status: "draft" | "published" | "retired";
  parentId: string | null; iconAssetId: string | null; iconPath: string | null; activities: number;
};
export async function listCategories(db: Db): Promise<Category[]> {
  const rows = must(await db.from("categories")
    .select("id, key, name, sort, status, parent_id, icon_asset_id, icon:media_assets!categories_icon_asset_id_fkey(object_path), activities!activities_primary_category_id_fkey(count)")
    .order("sort"));
  return rows.map((r: Row) => ({
    id: r.id, key: r.key, name: en(r.name), sort: r.sort, status: r.status, parentId: r.parent_id,
    iconAssetId: r.icon_asset_id, iconPath: r.icon?.object_path ?? null, activities: r.activities?.[0]?.count ?? 0,
  }));
}
export async function saveCategory(db: Db, v: In<typeof categoryInput>, id?: string) {
  const row = { key: v.key, sort: v.sort, parent_id: v.parentId, icon_asset_id: v.iconAssetId };
  if (id) {
    if (v.parentId === id) throw new Error("A category can't be its own parent.");
    const old = must(await db.from("categories").select("name").eq("id", id).single());
    return must(await db.from("categories").update({ ...row, name: withEn(old.name, v.name) }).eq("id", id).select("id").single());
  }
  return must(await db.from("categories").insert({ ...row, name: { en: v.name } }).select("id").single());
}
/** Enable (published) or disable (retired) a category. Published categories need content.publish. */
export async function setCategoryEnabled(db: Db, id: string, enabled: boolean) {
  mustOne(await db.from("categories").update({ status: enabled ? "published" : "retired" }).eq("id", id).select("id"));
}
export async function deleteCategory(db: Db, id: string) {
  mustOne(await db.from("categories").delete().eq("id", id).select("id"));
}

// ---------------------------------------------------------------- activities
export type ActivityRow = {
  id: string; slug: string; type: string; title: string; status: Status; subject: string | null;
  ageMin: number; ageMax: number; updatedAt: string; plusOnly: boolean;
};
export async function listActivities(
  db: Db, f: { q?: string; type?: string; status?: string; subjectId?: string; page?: number; pageSize?: number },
): Promise<Page<ActivityRow>> {
  const r = range(f.page ?? 1, Math.min(f.pageSize ?? PAGE_SIZE, 100));
  let query = db.from("activities")
    .select("id, slug, type, title, status, age_min_months, age_max_months, updated_at, plus_only, subjects(name)", { count: "exact" });
  if (f.q) query = query.or(`slug.ilike.${like(f.q)},title->>en.ilike.${like(f.q)},keywords.ilike.${like(f.q)}`);
  if (f.type) query = query.eq("type", f.type);
  if (f.status) query = query.eq("status", f.status);
  if (f.subjectId) query = query.eq("subject_id", f.subjectId);
  const res = await query.order("updated_at", { ascending: false }).range(r.from, r.to);
  const rows = must(res);
  return {
    rows: rows.map((a: Row) => ({
      id: a.id, slug: a.slug, type: a.type, title: en(a.title), status: a.status, subject: a.subjects ? en(a.subjects.name) : null,
      ageMin: a.age_min_months, ageMax: a.age_max_months, updatedAt: a.updated_at, plusOnly: a.plus_only,
    })),
    total: res.count ?? 0, page: r.page, pageSize: r.size,
  };
}

export type Activity = {
  id: string; slug: string; type: string; title: string; description: string; keywords: string; status: Status;
  subjectId: string | null; categoryId: string | null; thumbnailAssetId: string | null; thumbnailPath: string | null;
  ageMin: number; ageMax: number; difficulty: number; estimatedSeconds: number | null; plusOnly: boolean;
  freeEligible: boolean; contentVersion: number; publishedAt: string | null; updatedAt: string;
};
export async function getActivity(db: Db, id: string): Promise<Activity> {
  const a = must(await db.from("activities")
    .select("*, thumb:media_assets!activities_thumbnail_asset_id_fkey(object_path)").eq("id", id).single());
  return {
    id: a.id, slug: a.slug, type: a.type, title: en(a.title), description: en(a.description), keywords: a.keywords,
    status: a.status, subjectId: a.subject_id, categoryId: a.primary_category_id, thumbnailAssetId: a.thumbnail_asset_id,
    thumbnailPath: a.thumb?.object_path ?? null, ageMin: a.age_min_months, ageMax: a.age_max_months, difficulty: a.difficulty,
    estimatedSeconds: a.estimated_seconds, plusOnly: a.plus_only, freeEligible: a.free_eligible,
    contentVersion: a.content_version, publishedAt: a.published_at, updatedAt: a.updated_at,
  };
}
export async function saveActivity(db: Db, v: In<typeof activityInput>, id?: string): Promise<{ id: string }> {
  const row = {
    slug: v.slug, keywords: v.keywords, subject_id: v.subjectId, primary_category_id: v.categoryId,
    thumbnail_asset_id: v.thumbnailAssetId, age_min_months: v.ageMin, age_max_months: v.ageMax,
    difficulty: v.difficulty, estimated_seconds: v.estimatedSeconds ?? null, plus_only: v.plusOnly, free_eligible: v.freeEligible,
  };
  if (id) {
    const old = must(await db.from("activities").select("title, description").eq("id", id).single());
    return must(await db.from("activities")
      .update({ ...row, title: withEn(old.title, v.title), description: withEn(old.description, v.description) })
      .eq("id", id).select("id").single());
  }
  const created = must(await db.from("activities")
    .insert({ ...row, type: v.type, title: { en: v.title }, description: v.description ? { en: v.description } : {} })
    .select("id").single());
  if (v.type === "game") {
    // every game runs on the learning engine template (Phases 9–10)
    const t = must(await db.from("game_templates").select("id").eq("key", "learning_engine").order("version", { ascending: false }).limit(1).single());
    must(await db.from("games").insert({ activity_id: created.id, template_id: t.id, config: { items: [] } }));
  }
  return created;
}
export async function deleteActivity(db: Db, id: string) {
  mustOne(await db.from("activities").delete().eq("id", id).select("id"));
}

// ---------------------------------------------------------------- courses
export type CourseRow = { id: string; slug: string; title: string; status: Status; stage: string; lessons: number; updatedAt: string; sort: number };
export async function listCourses(db: Db, f: { q?: string; status?: string; page?: number }): Promise<Page<CourseRow>> {
  const r = range(f.page ?? 1);
  let query = db.from("courses").select("id, slug, title, status, stage, updated_at, sort, course_modules(lessons(count))", { count: "exact" });
  if (f.q) query = query.or(`slug.ilike.${like(f.q)},title->>en.ilike.${like(f.q)}`);
  if (f.status) query = query.eq("status", f.status);
  const res = await query.order("sort").order("updated_at", { ascending: false }).range(r.from, r.to);
  return {
    rows: must(res).map((c: Row) => ({
      id: c.id, slug: c.slug, title: en(c.title), status: c.status, stage: c.stage, updatedAt: c.updated_at, sort: c.sort,
      lessons: (c.course_modules ?? []).reduce((n: number, m: { lessons?: { count: number }[] }) => n + (m.lessons?.[0]?.count ?? 0), 0),
    })),
    total: res.count ?? 0, page: r.page, pageSize: r.size,
  };
}

export type Step = { id: string; position: number; type: string; required: boolean; activityId: string; activityTitle: string; activityStatus: Status; activityType: string };
export type Lesson = {
  id: string; moduleId: string; position: number; title: string; description: string; instructions: string;
  objectives: string[]; estimatedMinutes: number | null; coverAssetId: string | null; prerequisites: string[]; steps: Step[];
};
export type Module = { id: string; position: number; title: string; lessons: Lesson[] };
export type Course = {
  id: string; slug: string; title: string; description: string; status: Status; stage: string; subjectId: string | null;
  categoryId: string | null; difficulty: number; objectives: string[]; coverAssetId: string | null; coverPath: string | null;
  plusOnly: boolean; sort: number; publishedAt: string | null; modules: Module[];
};
const byPos = <T extends { position: number }>(a: T, b: T) => a.position - b.position;
export async function getCourse(db: Db, id: string): Promise<Course> {
  const c = must(await db.from("courses").select(
    "*, cover:media_assets!courses_cover_asset_id_fkey(object_path), course_modules(id, position, title, lessons(id, module_id, position, title, description, instructions, objectives, estimated_minutes, cover_asset_id, prerequisite_lesson_ids, lesson_steps(id, position, step_type, required, activity_id, activities(title, status, type))))",
  ).eq("id", id).single());
  return {
    id: c.id, slug: c.slug, title: en(c.title), description: en(c.description), status: c.status, stage: c.stage,
    subjectId: c.subject_id, categoryId: c.category_id, difficulty: c.difficulty, objectives: c.objectives ?? [],
    coverAssetId: c.cover_asset_id, coverPath: c.cover?.object_path ?? null, plusOnly: c.plus_only, sort: c.sort, publishedAt: c.published_at,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    modules: (c.course_modules ?? []).map((m: any) => ({
      id: m.id, position: m.position, title: en(m.title),
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      lessons: (m.lessons ?? []).map((l: any) => ({
        id: l.id, moduleId: l.module_id, position: l.position, title: en(l.title), description: en(l.description),
        instructions: en(l.instructions), objectives: l.objectives ?? [], estimatedMinutes: l.estimated_minutes,
        coverAssetId: l.cover_asset_id, prerequisites: l.prerequisite_lesson_ids ?? [],
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        steps: (l.lesson_steps ?? []).map((s: any) => ({
          id: s.id, position: s.position, type: s.step_type, required: s.required, activityId: s.activity_id,
          activityTitle: en(s.activities?.title), activityStatus: s.activities?.status, activityType: s.activities?.type,
        })).sort(byPos),
      })).sort(byPos),
    })).sort(byPos),
  };
}
export async function saveCourse(db: Db, v: In<typeof courseInput>, id?: string): Promise<{ id: string }> {
  const row = {
    slug: v.slug, subject_id: v.subjectId, category_id: v.categoryId, stage: v.stage, difficulty: v.difficulty,
    cover_asset_id: v.coverAssetId, objectives: v.objectives, plus_only: v.plusOnly, sort: v.sort,
  };
  if (id) {
    const old = must(await db.from("courses").select("title, description").eq("id", id).single());
    return must(await db.from("courses").update({ ...row, title: withEn(old.title, v.title), description: withEn(old.description, v.description) })
      .eq("id", id).select("id").single());
  }
  return must(await db.from("courses").insert({ ...row, title: { en: v.title }, description: v.description ? { en: v.description } : {} })
    .select("id").single());
}
export async function deleteCourse(db: Db, id: string) {
  mustOne(await db.from("courses").delete().eq("id", id).select("id"));
}

/** Moves a row within its parent by swapping positions (unique per parent: via a free slot). */
async function swap(db: Db, table: string, parentCol: string, id: string, dir: -1 | 1) {
  const me = must(await db.from(table).select(`id, position, ${parentCol}`).eq("id", id).single()) as Record<string, string | number>;
  const sibs = must(await db.from(table).select("id, position").eq(parentCol, me[parentCol]).order("position")) as { id: string; position: number }[];
  const i = sibs.findIndex((s) => s.id === id);
  const other = sibs[i + dir];
  if (!other) return;
  const free = Math.max(...sibs.map((s: Row) => s.position)) + 1;
  mustOne(await db.from(table).update({ position: free }).eq("id", id).select("id"));
  mustOne(await db.from(table).update({ position: me.position }).eq("id", other.id).select("id"));
  mustOne(await db.from(table).update({ position: other.position }).eq("id", id).select("id"));
}
const nextPos = async (db: Db, table: string, parentCol: string, parent: string) => {
  const r = must(await db.from(table).select("position").eq(parentCol, parent).order("position", { ascending: false }).limit(1));
  return r.length ? r[0].position + 1 : 0;
};

export async function addModule(db: Db, courseId: string, title: string) {
  return must(await db.from("course_modules").insert({ course_id: courseId, position: await nextPos(db, "course_modules", "course_id", courseId), title: { en: title } }).select("id").single());
}
export async function renameModule(db: Db, id: string, title: string) {
  mustOne(await db.from("course_modules").update({ title: { en: title } }).eq("id", id).select("id"));
}
export async function deleteModule(db: Db, id: string) { mustOne(await db.from("course_modules").delete().eq("id", id).select("id")); }
export const moveModule = (db: Db, id: string, dir: -1 | 1) => swap(db, "course_modules", "course_id", id, dir);

export async function addLesson(db: Db, moduleId: string, title: string) {
  return must(await db.from("lessons").insert({ module_id: moduleId, position: await nextPos(db, "lessons", "module_id", moduleId), title: { en: title } }).select("id").single());
}
export async function saveLesson(db: Db, id: string, v: In<typeof lessonInput>) {
  const old = must(await db.from("lessons").select("title, description, instructions").eq("id", id).single());
  mustOne(await db.from("lessons").update({
    title: withEn(old.title, v.title), description: withEn(old.description, v.description),
    instructions: withEn(old.instructions, v.instructions), objectives: v.objectives,
    estimated_minutes: v.estimatedMinutes ?? null, cover_asset_id: v.coverAssetId, prerequisite_lesson_ids: v.prerequisites,
  }).eq("id", id).select("id"));
}
export async function deleteLesson(db: Db, id: string) { mustOne(await db.from("lessons").delete().eq("id", id).select("id")); }
export const moveLesson = (db: Db, id: string, dir: -1 | 1) => swap(db, "lessons", "module_id", id, dir);

export async function addStep(db: Db, lessonId: string, activityId: string, type: string, required = true) {
  return must(await db.from("lesson_steps").insert({
    lesson_id: lessonId, activity_id: activityId, step_type: type, required,
    position: await nextPos(db, "lesson_steps", "lesson_id", lessonId),
  }).select("id").single());
}
export async function setStepRequired(db: Db, id: string, required: boolean) {
  mustOne(await db.from("lesson_steps").update({ required }).eq("id", id).select("id"));
}
export async function deleteStep(db: Db, id: string) { mustOne(await db.from("lesson_steps").delete().eq("id", id).select("id")); }
export const moveStep = (db: Db, id: string, dir: -1 | 1) => swap(db, "lesson_steps", "lesson_id", id, dir);

// ---------------------------------------------------------------- workflow
export async function validateContent(db: Db, table: "activities" | "courses", id: string): Promise<string[]> {
  return must(await db.schema("admin_api").rpc("validate", { p_table: table, p_id: id })) as string[];
}
export async function transition(db: Db, table: "activities" | "courses", id: string, to: Status, note?: string) {
  return must(await db.schema("admin_api").rpc("transition", { p_table: table, p_id: id, p_to: to, p_note: note ?? null }));
}
export type QueueItem = { table: "activities" | "courses"; id: string; title: string; kind: string; status: Status; updatedAt: string };
export async function reviewQueue(db: Db): Promise<QueueItem[]> {
  const [a, c] = await Promise.all([
    db.from("activities").select("id, title, type, status, updated_at").in("status", ["in_review", "approved"]).order("updated_at"),
    db.from("courses").select("id, title, status, updated_at").in("status", ["in_review", "approved"]).order("updated_at"),
  ]);
  return [
    ...must(a).map((x: Row) => ({ table: "activities" as const, id: x.id, title: en(x.title), kind: x.type, status: x.status, updatedAt: x.updated_at })),
    ...must(c).map((x: Row) => ({ table: "courses" as const, id: x.id, title: en(x.title), kind: "course", status: x.status, updatedAt: x.updated_at })),
  ].sort((x, y) => x.updatedAt.localeCompare(y.updatedAt));
}
/** The workflow history of one item (from the audit log; needs content.read). */
/** An item's recent changes (an activity's include its game config). */
export async function history(db: Db, table: string, id: string) {
  const tables = table === "activities" ? ["activities", "games"] : [table];
  const lists = await Promise.all(tables.map(async (t) => must(await db.schema("admin_api").rpc("activity", { p_limit: 200, p_offset: 0, p_table: t })) as AuditRow[]));
  return lists.flat().filter((r) => r.entityId === id).sort((a, b) => (a.at < b.at ? 1 : a.at > b.at ? -1 : b.id - a.id));
}
export type AuditRow = { id: number; at: string; actorType: string; actor: string | null; action: string; table: string; entityId: string | null; changes: Record<string, unknown> };
