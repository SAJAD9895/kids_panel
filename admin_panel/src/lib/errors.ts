// Turns database and API errors into sentences for admins. The codes are the platform's KL4xx
// codes (private.fail), Postgres codes from RLS / constraints, and PostgREST's own.
export type DbError = { code?: string; message?: string; details?: string | null; hint?: string | null };

export class AdminError extends Error {
  constructor(message: string, readonly code?: string) {
    super(message);
  }
}

export function friendly(e: DbError | null | undefined): string {
  if (!e) return "Something went wrong. Try again.";
  const detail = (e.details ?? "").trim();
  switch (e.code) {
    case "KL400": return detail ? `Check the details: ${detail}` : "Some details weren't accepted.";
    case "KL403": return detail ? `Not allowed: ${detail}.` : "You don't have permission for this.";
    case "KL404": return detail ? `Not found: ${detail}.` : "That no longer exists.";
    case "KL409": return detail ? `${detail[0].toUpperCase()}${detail.slice(1)}.` : "That conflicts with the current state.";
    case "KL429": return "Too many requests. Wait a little and try again.";
    case "42501": return "You don't have permission for this (or the content is live and needs a content manager).";
    case "23505": return "That key or slug is already used. Choose another.";
    case "23503": return "It's still used elsewhere, so it can't be removed.";
    case "23514": return `A value isn't allowed${e.message ? `: ${e.message}` : ""}.`;
    case "PGRST116": return "That no longer exists.";
    case "PGRST301": case "PGRST303": return "Your session has expired. Sign in again.";
    default: return e.message || "Something went wrong. Try again.";
  }
}

/**
 * Throws a readable error when a Supabase call failed; otherwise returns the rows. Untyped on
 * purpose (no generated database types yet): each data function maps rows into its own type.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function must(res: { data: unknown; error: DbError | null }): any {
  // a page past the end of a list (an old link, ?page=99): PostgREST answers 416; show it empty
  if (res.error?.code === "PGRST103") return [];
  if (res.error) throw new AdminError(friendly(res.error), res.error.code);
  return res.data;
}

/** For an update or delete by id (with .select("id")): RLS hides rows the caller may not change,
 * so "nothing changed" means not allowed (or already gone), never a silent success. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function mustOne(res: { data: any; error: any }) {
  const rows = must(res);
  if (!Array.isArray(rows) || rows.length === 0) throw new AdminError("You don't have permission for this, or it no longer exists.");
  return rows;
}
