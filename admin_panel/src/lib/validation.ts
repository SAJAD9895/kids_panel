// Input rules shared by forms (client hints) and server actions (the real check). The database
// re-checks with constraints; these give clear messages first.
import { z } from "zod";

export const slug = z.string().trim().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "lower-case letters, numbers and dashes").max(60);
export const key = z.string().trim().regex(/^[a-z0-9_]+$/, "lower-case letters, numbers and _").max(40);
export const text = (max = 200) => z.string().trim().min(1, "required").max(max);
export const optionalText = (max = 2000) => z.string().trim().max(max).optional().transform((v) => v || undefined);
export const uuid = z.string().uuid();
export const optionalUuid = z.string().optional().transform((v) => v || null).pipe(z.string().uuid().nullable());
export const int = (min: number, max: number) => z.coerce.number().int().min(min).max(max);
export const bool = z.union([z.literal("on"), z.literal("true"), z.literal("false"), z.boolean()]).optional()
  .transform((v) => v === true || v === "on" || v === "true");
/** One objective per line → ["…", "…"] (at most 8, 140 characters each). */
export const lines = z.string().optional().transform((v) =>
  (v ?? "").split("\n").map((s) => s.trim()).filter(Boolean)).pipe(z.array(z.string().max(140)).max(8));

export const STAGES = ["toddler", "preschool", "kindergarten", "grade1", "grade2"] as const;
export const STAGE_AGES: Record<(typeof STAGES)[number], string> = {
  toddler: "1–2 years", preschool: "3–4 years", kindergarten: "5 years", grade1: "6 years", grade2: "7 years",
};
export const ACTIVITY_TYPES = ["game", "quiz", "video", "song", "story", "audiobook"] as const;
export const STEP_TYPES = ["intro", "practice", "knowledge_check", "collect", "trace", "video", "story", "song", "review"] as const;
export const STATUSES = ["draft", "in_review", "approved", "published", "retired"] as const;
export type Status = (typeof STATUSES)[number];

export const subjectInput = z.object({ key, name: text(60), sort: int(0, 999) });
export const categoryInput = z.object({
  key, name: text(60), sort: int(0, 999), parentId: optionalUuid, iconAssetId: optionalUuid,
});
export const courseInput = z.object({
  slug, title: text(80), description: optionalText(600), subjectId: optionalUuid, categoryId: optionalUuid,
  stage: z.enum(STAGES), difficulty: int(1, 5), coverAssetId: optionalUuid, objectives: lines,
  plusOnly: bool, sort: int(0, 999),
});
export const lessonInput = z.object({
  title: text(80), description: optionalText(600), instructions: optionalText(600), objectives: lines,
  estimatedMinutes: z.coerce.number().int().min(1).max(120).optional().or(z.literal("").transform(() => undefined)),
  coverAssetId: optionalUuid, prerequisites: z.array(uuid).max(10).default([]),
});
export const activityInput = z.object({
  slug, type: z.enum(ACTIVITY_TYPES), title: text(80), description: optionalText(600), keywords: z.string().trim().max(200).default(""),
  subjectId: optionalUuid, categoryId: optionalUuid, thumbnailAssetId: optionalUuid,
  ageMin: int(0, 144), ageMax: int(0, 144), difficulty: int(1, 5),
  estimatedSeconds: z.coerce.number().int().min(10).max(3600).optional().or(z.literal("").transform(() => undefined)),
  plusOnly: bool, freeEligible: bool,
}).refine((v) => v.ageMin <= v.ageMax, { message: "the youngest age must be under the oldest", path: ["ageMax"] });
export const transitionInput = z.object({
  table: z.enum(["activities", "courses"]), id: uuid, to: z.enum(STATUSES), note: optionalText(500),
});

/** zod issues → "field: message" lines for the form. */
export function problems(e: z.ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const i of e.issues) out[i.path.join(".") || "_"] = i.message;
  return out;
}
