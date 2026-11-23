// /children routes (docs/architecture/07-api-specification.md):
//   POST   /children        add a child (plan limit → 402 CHILD_LIMIT)
//   PATCH  /children/:id    edit (partial)
//   DELETE /children/:id    delete now; owner only; needs a sign-in in the last 10 minutes
//   PUT    /children/:id/screen-time   the parent's media controls: section switches, blocked
//                                      categories, optional daily limit (Phase 11)
//   GET    /children/:id/rewards       stars, badges, goals, streak, history (Phase 12)
//   PUT    /children/:id/goals         the parent's daily / weekly learning goals (Phase 12)
import { HttpError, json, noContent, readJson, routeParts, serve } from "../_shared/http.ts";
import { requireRecentSignIn, requireUser } from "../_shared/auth.ts";
import { db } from "../_shared/db.ts";
import { birthYearMonth, childInput, locale, nickname, parse, stage, uuid, z } from "../_shared/validate.ts";

const patchBody = z.object({
  nickname: nickname.optional(),
  birthYearMonth: birthYearMonth.optional(),
  avatarId: uuid.nullable().optional(),
  stage: stage.optional(),
  contentLocale: locale.nullable().optional(),
}).strict().refine((b) => Object.keys(b).length > 0, "nothing to change");

const screenTimeBody = z.object({
  dailyLimitMinutes: z.number().int().min(5).max(600).nullable().optional(),
  limitedSections: z.array(z.enum(["learn", "watch", "listen", "together"])).max(4).optional(),
  learnEnabled: z.boolean().optional(),
  watchEnabled: z.boolean().optional(),
  listenEnabled: z.boolean().optional(),
  togetherEnabled: z.boolean().optional(),
  blockedCategoryIds: z.array(uuid).max(50).optional(),
}).strict();

const goalsBody = z.object({
  enabled: z.boolean().optional(),
  dailyActivities: z.number().int().min(1).max(10).optional(),
  weeklyDays: z.number().int().min(1).max(7).optional(),
}).strict().refine((b) => Object.keys(b).length > 0, "nothing to change");

serve(async (req) => {
  const caller = await requireUser(req);
  const [id, extra] = routeParts(req, "children");
  if (extra === "rewards") {
    if (req.method !== "GET") throw new HttpError("METHOD_NOT_ALLOWED");
    const childId = parse(uuid, id);
    const [row] = await db()`select private.rewards_summary(${caller.userId}::uuid, ${childId}::uuid) as r`;
    return json(row.r);
  }
  if (extra === "goals") {
    if (req.method !== "PUT") throw new HttpError("METHOD_NOT_ALLOWED");
    const childId = parse(uuid, id);
    const goals = parse(goalsBody, await readJson(req));
    const [row] = await db()`
      select private.set_learning_goals(${caller.userId}::uuid, ${childId}::uuid, ${db().json(goals)}::jsonb) as r`;
    return json(row.r);
  }
  if (extra === "screen-time") {
    if (req.method !== "PUT") throw new HttpError("METHOD_NOT_ALLOWED");
    const childId = parse(uuid, id);
    const rules = parse(screenTimeBody, await readJson(req));
    const [row] = await db()`
      select private.set_screen_time_rules(${caller.userId}::uuid, ${childId}::uuid, ${db().json(rules)}::jsonb) as r`;
    return json(row.r);
  }
  if (extra !== undefined) throw new HttpError("NOT_FOUND");

  if (!id) {
    if (req.method !== "POST") throw new HttpError("METHOD_NOT_ALLOWED");
    const child = parse(childInput, await readJson(req));
    const [row] = await db()`select private.add_child(${caller.userId}::uuid, ${db().json(child)}::jsonb) as r`;
    return json(row.r, 201);
  }

  const childId = parse(uuid, id);
  switch (req.method) {
    case "PATCH": {
      const patch = parse(patchBody, await readJson(req));
      const [row] = await db()`
        select private.update_child(${caller.userId}::uuid, ${childId}::uuid, ${db().json(patch)}::jsonb) as r`;
      return json(row.r);
    }
    case "DELETE": {
      requireRecentSignIn(caller);
      await db()`select private.delete_child(${caller.userId}::uuid, ${childId}::uuid)`;
      return noContent();
    }
    default:
      throw new HttpError("METHOD_NOT_ALLOWED");
  }
});
