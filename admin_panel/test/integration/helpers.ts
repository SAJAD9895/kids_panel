import { createClient } from "@supabase/supabase-js";
import { inject } from "vitest";
import pg from "pg";
import type { Db } from "@/lib/data/db";

export const stack = () => inject("stack");
export const PASSWORD = "Admin-pass-123";
export const CODE = "123456";

/** A client signed in as [email]; with mfa (default) the session is aal2, like the admin app's. */
export async function login(email: string, mfa = true): Promise<Db> {
  const { url, anonKey } = stack();
  const db = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { error } = await db.auth.signInWithPassword({ email, password: PASSWORD });
  if (error) throw error;
  if (mfa) {
    const { data } = await db.auth.mfa.listFactors();
    const f = data?.totp[0];
    if (!f) throw new Error(`${email} has no factor`);
    const v = await db.auth.mfa.challengeAndVerify({ factorId: f.id, code: CODE });
    if (v.error) throw v.error;
  }
  return db as Db;
}
export const token = async (db: Db) => (await db.auth.getSession()).data.session!.access_token;

let pool: pg.Pool | undefined;
/** Direct database access (as the owner) for checking results and server-only functions. */
export const sql = async (q: string, params: unknown[] = []) => {
  pool ??= new pg.Pool({ connectionString: stack().dbUrl, max: 2 });
  return (await pool.query(q, params)).rows;
};
export const uid = () => Math.random().toString(36).slice(2, 8);
