// Request schemas (zod). Unknown fields are stripped before anything reaches SQL.
// The SQL functions validate again (defence in depth); these give early, readable 400s.
import { z } from "npm:zod@3.23.8";
import { HttpError } from "./http.ts";

export const nickname = z.string().trim().min(1).max(20);
export const birthYearMonth = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, "YYYY-MM");
export const uuid = z.string().uuid();
export const stage = z.enum(["auto", "toddler", "preschool", "kindergarten", "grade1", "grade2"]);
export const locale = z.string().regex(/^[a-z]{2}(-[A-Z]{2})?$/);

export const childInput = z.object({
  nickname,
  birthYearMonth,
  avatarId: uuid.nullish(),
  stage: stage.optional(),
  contentLocale: locale.optional(),
});

export function parse<T extends z.ZodTypeAny>(schema: T, body: unknown): z.infer<T> {
  const r = schema.safeParse(body);
  if (!r.success) {
    const first = r.error.issues[0];
    throw new HttpError("VALIDATION", `${first.path.join(".") || "body"}: ${first.message}`);
  }
  return r.data;
}

export { z };
