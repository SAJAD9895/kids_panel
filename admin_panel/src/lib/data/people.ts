// Families, privacy requests and support actions — all through admin_api functions that check
// support / privacy permissions and return only what support needs (no birth months, no sessions).
import { must } from "../errors";
import type { Db } from "./db";

const api = (db: Db) => db.schema("admin_api");

export type FamilyRow = { accountId: string; ownerEmail: string; status: string; country: string | null; createdAt: string; children: number; plus: boolean };
export async function listFamilies(db: Db, f: { q?: string; status?: string; page?: number }, size = 25) {
  const page = Math.max(1, f.page ?? 1);
  const r = must(await api(db).rpc("families", { p_query: f.q ?? "", p_status: f.status || null, p_limit: size, p_offset: (page - 1) * size })) as { total: number; rows: FamilyRow[] };
  return { ...r, page, pageSize: size };
}
export type FamilyDetail = {
  accountId: string; status: string; timezone: string; country: string | null; createdAt: string;
  parents: { email: string; role: string; since: string }[];
  children: { childId: string; nickname: string; ageYears: number; status: string; sessions30d: number; completed30d: number; lastActive: string | null; stars: number }[];
  subscriptions: { plan: string; provider: string; status: string; periodEnd: string | null; environment: string }[];
  exports: { id: string; status: string; childId: string | null; createdAt: string; expiresAt: string | null }[];
  deletions: { id: string; scope: string; status: string; scheduledFor: string }[];
};
export const getFamily = async (db: Db, id: string) => must(await api(db).rpc("family", { p_account: id })) as FamilyDetail;
export const setAccountStatus = async (db: Db, id: string, status: "active" | "suspended", reason: string) =>
  must(await api(db).rpc("set_account_status", { p_account: id, p_status: status, p_reason: reason }));
export const grantStars = async (db: Db, childId: string, amount: number, reason: string, requestId: string) =>
  must(await api(db).rpc("grant_stars", { p_child: childId, p_amount: amount, p_reason: reason, p_request: requestId })) as { granted: boolean; balance: number };
export const cancelDeletion = async (db: Db, id: string, reason: string) =>
  must(await api(db).rpc("cancel_deletion", { p_request: id, p_reason: reason }));

export type PrivacyRow = { id: string; accountId: string; ownerEmail: string; status: string; scope: string; createdAt: string; scheduledFor?: string; expiresAt?: string | null; completedAt?: string | null };
export async function privacyRequests(db: Db, kind: "export" | "deletion", status?: string, page = 1, size = 25) {
  return must(await api(db).rpc("privacy_requests", { p_kind: kind, p_status: status || null, p_limit: size, p_offset: (page - 1) * size })) as PrivacyRow[];
}
