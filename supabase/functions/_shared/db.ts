// Database connection for the private.* operations (docs/backend/api-design.md §3).
// SUPABASE_DB_URL is provided by the platform; use the Supavisor transaction pooler (port 6543),
// which doesn't support prepared statements, hence prepare: false.
import postgres from "npm:postgres@3.4.5";

let sql: ReturnType<typeof postgres> | undefined;

export function db() {
  sql ??= postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 2, idle_timeout: 20 });
  return sql;
}

/** A jsonb parameter: `${jsonb(value)}::jsonb`. Never pass JSON.stringify(value) — postgres.js
 * would encode the string again and the function would receive a JSON string, not an object. */
export const jsonb = (value: unknown) => db().json(value as Parameters<ReturnType<typeof db>["json"]>[0]);
