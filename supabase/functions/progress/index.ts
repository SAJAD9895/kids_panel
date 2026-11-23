// Parent reports (Phase 13, docs/parent-dashboard/):
//   GET /progress/overview                              every child of the household (dashboard)
//   GET /progress/report?childId=&period=day|week|month&date=YYYY-MM-DD   one child's report
// The user comes from the JWT; the SQL functions check the household. Read-only.
import { HttpError, json, routeParts, serve } from "../_shared/http.ts";
import { requireUser } from "../_shared/auth.ts";
import { db } from "../_shared/db.ts";
import { parse, uuid, z } from "../_shared/validate.ts";

const reportQuery = z.object({
  childId: uuid,
  period: z.enum(["day", "week", "month"]).default("week"),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
}).strict();

serve(async (req) => {
  if (req.method !== "GET") throw new HttpError("METHOD_NOT_ALLOWED");
  const caller = await requireUser(req);
  const [route] = routeParts(req, "progress");
  if (route === "overview") {
    const [row] = await db()`select private.family_overview(${caller.userId}::uuid) as r`;
    return json(row.r);
  }
  if (route === "report") {
    const q = parse(reportQuery, Object.fromEntries(new URL(req.url).searchParams));
    const [row] = await db()`
      select private.progress_report(${caller.userId}::uuid, ${q.childId}::uuid, ${q.period}, ${q.date ?? null}::date) as r`;
    return json(row.r);
  }
  throw new HttpError("NOT_FOUND");
});
