import type { SupabaseClient } from "@supabase/supabase-js";

// Untyped on purpose: types would come from `supabase gen types` against a live project.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Db = SupabaseClient<any, "public", any>;
/** A row as returned by the API (untyped; mapped into explicit types by each data function). */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Row = any;

/** Localized text column ({en: …, es: …}) → the English text. */
export const en = (v: unknown): string =>
  typeof v === "string" ? v : v && typeof v === "object" ? String((v as Record<string, unknown>).en ?? "") : "";

/** Sets the English text, keeping other languages. */
export const withEn = (old: unknown, value: string | undefined) => {
  const base = old && typeof old === "object" ? { ...(old as Record<string, string>) } : {};
  if (value) base.en = value;
  else delete base.en;
  return base;
};

export type Page<T> = { rows: T[]; total: number; page: number; pageSize: number };
export const PAGE_SIZE = 20;
export const range = (page: number, size = PAGE_SIZE) => {
  const p = Math.max(1, Math.floor(page) || 1);
  return { from: (p - 1) * size, to: p * size - 1, page: p, size };
};
/** Escapes a search term for PostgREST ilike filters. */
export const like = (q: string) => `%${q.replace(/[%_,()]/g, " ").trim()}%`;
