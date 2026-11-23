// Admin users, roles and settings, the dashboard and the activity log.
import { AdminError, must, mustOne } from "../errors";
import type { AuditRow } from "./content";
import type { Db, Row } from "./db";

const api = (db: Db) => db.schema("admin_api");

export type Me = { userId: string; email: string; status: string; aal: string; roles: string[]; permissions: string[] };
export const me = async (db: Db) => must(await api(db).rpc("me")) as Me | null;

export type Dashboard = {
  parents: number; families: number; children: number; activeSubscriptions: number; courses: number; lessons: number;
  games: number; activities: number; published: number; inReview: number; approved: number; drafts: number; mediaFailed: number;
};
export const dashboard = async (db: Db) => must(await api(db).rpc("dashboard")) as Dashboard;
export const activity = async (db: Db, page = 1, size = 25, table?: string) =>
  must(await api(db).rpc("activity", { p_limit: size, p_offset: (page - 1) * size, p_table: table || null })) as AuditRow[];

export type AdminUser = { userId: string; email: string; status: string; roles: string[]; since: string; lastSignIn: string | null };
export const adminUsers = async (db: Db) => must(await api(db).rpc("users_list")) as AdminUser[];
export async function setRoles(db: Db, email: string, roles: string[]) {
  if (!/^\S+@\S+\.\S+$/.test(email.trim())) throw new AdminError("Enter the person's email address.");
  return must(await api(db).rpc("set_roles", { p_email: email.trim(), p_roles: roles }));
}
export const setAdminStatus = async (db: Db, userId: string, status: "active" | "suspended") =>
  must(await api(db).rpc("set_admin_status", { p_user: userId, p_status: status }));

export type RoleMatrix = { roles: { key: string; description: string }[]; permissions: { key: string; description: string }[]; grants: Set<string> };
export async function roleMatrix(db: Db): Promise<RoleMatrix> {
  const [roles, perms, grants] = await Promise.all([
    db.from("admin_roles").select("key, description").order("key"),
    db.from("admin_permissions").select("key, description").order("key"),
    db.from("admin_role_permissions").select("role_key, permission_key"),
  ]);
  return { roles: must(roles), permissions: must(perms), grants: new Set(must(grants).map((g: Row) => `${g.role_key}|${g.permission_key}`)) };
}

export type Setting = { key: string; value: unknown; description: string; updatedAt: string };
export const settings = async (db: Db) =>
  must(await db.from("app_config").select("key, value, description, updated_at").order("key")).map((s: Row) => ({ key: s.key, value: s.value, description: s.description, updatedAt: s.updated_at })) as Setting[];
/** Parses the text the admin typed into the setting's JSON type (the database re-checks it). */
export function parseSetting(key: string, raw: string): unknown {
  const v = raw.trim();
  if (key === "content.review_required") {
    if (v !== "true" && v !== "false") throw new AdminError("Use true or false.");
    return v === "true";
  }
  if (key === "media.allowed_types") return v.split(/[\s,]+/).filter(Boolean);
  if (/^\d+$/.test(v)) return Number(v);
  throw new AdminError("Use a whole number.");
}
export async function saveSetting(db: Db, key: string, raw: string) {
  mustOne(await db.from("app_config").update({ value: parseSetting(key, raw) }).eq("key", key).select("key"));
}
