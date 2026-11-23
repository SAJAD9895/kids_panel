import "server-only";
// The published catalogue, read as the parent through the Data API (RLS: published rows only).
// Same queries as the Flutter app (kids_app/lib/features/learning/data/supabase_learning_repositories.dart).
import { t } from "../format";
import { publicUrl } from "../media";
import type { Db } from "./db";

export type ActivityType = "game" | "quiz" | "video" | "song" | "story" | "audio_story" | "printable" | "together";
export type Activity = {
  id: string; slug: string; type: ActivityType; title: string; description: string; subjectId: string | null;
  ageMin: number; ageMax: number; seconds: number | null; plusOnly: boolean; categoryId: string | null; thumb: string | null;
};
export type Subject = { id: string; key: string; name: string };
export type Category = { id: string; key: string; name: string };
export type CourseSummary = { id: string; slug: string; title: string; description: string; subjectId: string | null; stage: string; plusOnly: boolean; together: boolean; lessonCount: number };
export type Path = { id: string; slug: string; title: string; description: string; ageMin: number; ageMax: number; courseIds: string[] };
export type Collection = { id: string; slug: string; surface: string; kind: string; title: string; ageMin: number | null; ageMax: number | null; activityIds: string[] };
export type Catalog = { subjects: Subject[]; activities: Activity[]; courses: CourseSummary[]; paths: Path[]; collections: Collection[]; categories: Category[] };

export const activityCols =
  "id, slug, type, title, description, subject_id, age_min_months, age_max_months, estimated_seconds, plus_only, players, primary_category_id, thumbnail:media_assets!activities_thumbnail_asset_id_fkey(object_path)";

type Row = Record<string, unknown>;
const num = (v: unknown, d = 0) => (typeof v === "number" ? v : d);
export const activityFrom = (r: Row): Activity => ({
  id: r.id as string, slug: r.slug as string, type: r.type as ActivityType, title: t(r.title), description: t(r.description),
  subjectId: (r.subject_id as string) ?? null, ageMin: num(r.age_min_months, 24), ageMax: num(r.age_max_months, 96),
  seconds: (r.estimated_seconds as number) ?? null, plusOnly: !!r.plus_only, categoryId: (r.primary_category_id as string) ?? null,
  thumb: publicUrl((r.thumbnail as { object_path?: string } | null)?.object_path),
});
const ok = <T,>(res: { data: T | null; error: { message: string } | null }): T => {
  if (res.error) throw new Error(res.error.message);
  return res.data as T;
};

export async function loadCatalog(db: Db): Promise<Catalog> {
  const [s, a, c, p, col, cat] = await Promise.all([
    db.from("subjects").select("id, key, name, sort").order("sort"),
    db.from("activities").select(activityCols).eq("status", "published").order("slug"),
    db.from("courses").select("id, slug, kind, title, description, subject_id, stage, plus_only, sort, course_modules(lessons(id))").eq("status", "published").order("sort"),
    db.from("learning_paths").select("id, slug, title, description, stage, age_min_months, age_max_months, learning_path_courses(course_id, position)").eq("status", "published"),
    db.from("collections").select("id, slug, surface, kind, title, age_min_months, age_max_months, sort, starts_at, ends_at, collection_items(activity_id, position)").eq("status", "published").order("sort"),
    db.from("categories").select("id, key, name, sort").eq("status", "published").order("sort"),
  ]);
  const now = Date.now();
  const live = (r: Row) => (!r.starts_at || Date.parse(r.starts_at as string) <= now) && (!r.ends_at || Date.parse(r.ends_at as string) > now);
  const byPos = (x: Row[]) => [...x].sort((m, n) => num(m.position) - num(n.position));
  return {
    subjects: ok(s).map((r: Row) => ({ id: r.id as string, key: r.key as string, name: t(r.name) })),
    activities: ok(a).map(activityFrom),
    courses: ok(c).map((r: Row) => ({
      id: r.id as string, slug: r.slug as string, title: t(r.title), description: t(r.description), subjectId: (r.subject_id as string) ?? null,
      stage: r.stage as string, plusOnly: !!r.plus_only, together: r.kind === "learn_together",
      lessonCount: ((r.course_modules as Row[]) ?? []).reduce((n, m) => n + ((m.lessons as Row[]) ?? []).length, 0),
    })),
    paths: ok(p).map((r: Row) => ({
      id: r.id as string, slug: r.slug as string, title: t(r.title), description: t(r.description), ageMin: num(r.age_min_months), ageMax: num(r.age_max_months, 999),
      courseIds: byPos((r.learning_path_courses as Row[]) ?? []).map((x) => x.course_id as string),
    })),
    collections: ok(col).filter(live).map((r: Row) => ({
      id: r.id as string, slug: r.slug as string, surface: r.surface as string, kind: r.kind as string, title: t(r.title),
      ageMin: (r.age_min_months as number) ?? null, ageMax: (r.age_max_months as number) ?? null,
      activityIds: byPos((r.collection_items as Row[]) ?? []).map((x) => x.activity_id as string),
    })),
    categories: ok(cat).map((r: Row) => ({ id: r.id as string, key: r.key as string, name: t(r.name) })),
  };
}

export type Step = { id: string; position: number; type: string; required: boolean; activity: Activity };
export type Lesson = { id: string; title: string; hasPrize: boolean; prerequisiteIds: string[]; steps: Step[]; estimatedMinutes: number | null };
export type CourseTree = { course: CourseSummary; lessons: Lesson[] };

export async function courseTree(db: Db, id: string): Promise<CourseTree | null> {
  const { data: r, error } = await db.from("courses").select(
    `id, slug, kind, title, description, subject_id, stage, plus_only, sort, status, course_modules(position, lessons(id, position, title, prize_reward_id, prerequisite_lesson_ids, estimated_minutes, lesson_steps(id, position, step_type, required, activities(${activityCols}))))`,
  ).eq("id", id).eq("status", "published").maybeSingle();
  if (error) throw new Error(error.message);
  if (!r) return null;
  const lessons: Lesson[] = [];
  for (const m of [...((r.course_modules as Row[]) ?? [])].sort((x, y) => num(x.position) - num(y.position))) {
    for (const l of [...((m.lessons as Row[]) ?? [])].sort((x, y) => num(x.position) - num(y.position))) {
      lessons.push({
        id: l.id as string, title: t(l.title), hasPrize: l.prize_reward_id != null, prerequisiteIds: ((l.prerequisite_lesson_ids as string[]) ?? []).map(String),
        estimatedMinutes: (l.estimated_minutes as number) ?? null,
        steps: [...((l.lesson_steps as Row[]) ?? [])].sort((x, y) => num(x.position) - num(y.position)).filter((s) => s.activities)
          .map((s) => ({ id: s.id as string, position: num(s.position), type: s.step_type as string, required: s.required !== false, activity: activityFrom(s.activities as Row) })),
      });
    }
  }
  const lessonCount = lessons.length;
  return { course: { id: r.id as string, slug: r.slug as string, title: t(r.title), description: t(r.description), subjectId: (r.subject_id as string) ?? null, stage: r.stage as string, plusOnly: !!r.plus_only, together: r.kind === "learn_together", lessonCount }, lessons };
}

export async function getActivity(db: Db, id: string) {
  const { data, error } = await db.from("activities").select(`${activityCols}, content_version, difficulty, games(config)`).eq("id", id).eq("status", "published").maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  const g = data.games as unknown as { config: unknown } | { config: unknown }[] | null;
  return { activity: activityFrom(data), contentVersion: (data.content_version as number) ?? 1, difficulty: (data.difficulty as number) ?? 1,
    config: (Array.isArray(g) ? g[0]?.config : g?.config) ?? null };
}

/** A quiz's question rows, exactly as the Flutter app reads them (play_data.dart); the engine's
 * quiz mapping turns them into items. */
export async function quizRows(db: Db, activityId: string): Promise<Row[]> {
  const { data, error } = await db.from("questions")
    .select("id, position, type, prompt, answers(id, position, content, is_correct, match_key, correct_order)")
    .eq("activity_id", activityId).order("position");
  if (error) throw new Error(error.message);
  return (data ?? []) as Row[];
}
