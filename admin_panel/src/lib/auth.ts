import "server-only";
import { redirect } from "next/navigation";
import { canAny, type Permission } from "./permissions";
import { me, type Me } from "./data/admin";
import { supabaseServer } from "./supabase/server";

export type Session =
  | { state: "signed_out" }
  | { state: "needs_mfa" }
  | { state: "not_admin" }
  | { state: "suspended" }
  | { state: "ok"; admin: Me };

/** Who is signed in, checked with Supabase Auth (not just the cookie) and the database. */
export async function session(): Promise<Session> {
  const db = await supabaseServer();
  const { data } = await db.auth.getUser();
  if (!data.user) return { state: "signed_out" };
  const { data: level } = await db.auth.mfa.getAuthenticatorAssuranceLevel();
  if (level?.currentLevel !== "aal2") return { state: "needs_mfa" };
  const admin = await me(db).catch(() => null);
  if (!admin) return { state: "not_admin" };
  if (admin.status !== "active") return { state: "suspended" };
  return { state: "ok", admin };
}

/** For pages and actions: the admin, or a redirect. With [any], one of those permissions is needed. */
export async function requireAdmin(any?: Permission[]) {
  const s = await session();
  if (s.state === "signed_out") redirect("/login");
  if (s.state === "needs_mfa") redirect("/login?step=mfa");
  if (s.state !== "ok") redirect(`/no-access?reason=${s.state}`);
  if (any && !canAny(s.admin.permissions, any)) redirect("/no-access?reason=permission");
  return { admin: s.admin, db: await supabaseServer() };
}
