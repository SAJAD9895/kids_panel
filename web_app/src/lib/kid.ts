import "server-only";
// Everything a child-zone page needs, loaded once per request: the chosen child, the catalogue
// filtered to what they may see, and their progress.
import { cache } from "react";
import { loadCatalog, type Activity } from "./data/catalog";
import { childProgress } from "./data/progress";
import { ageMonths, localDate } from "./format";
import { visibleTo } from "./rules";
import { requireChild } from "./session";

export const kidContext = cache(async (next = "/kids") => {
  const ctx = await requireChild(next);
  const today = localDate(ctx.family.timezone);
  const [catalog, progress] = await Promise.all([loadCatalog(ctx.db), childProgress(ctx.db, ctx.child.id, today)]);
  const months = ageMonths(ctx.child.birthYearMonth);
  const visible = catalog.activities.filter((a) => visibleTo(a, months, progress.switches));
  const byId = new Map(catalog.activities.map((a) => [a.id, a]));
  return { ...ctx, today, catalog, progress, months, visible, byId,
    /** Locked for this family (Plus content on Basic): shown with a lock, refused at launch. */
    locked: (a: Activity) => a.plusOnly && !progress.hasPlus };
});

export { hrefFor } from "./links";
