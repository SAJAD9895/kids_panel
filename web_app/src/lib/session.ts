import "server-only";
// Who is using the web app. Grown-up pages need a parent session, a finished family set-up and
// the parental gate; the child zone needs a parent session and a chosen child. Every read below
// runs as the parent under RLS, so a child id from a cookie can only ever be one of theirs.
import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { supabaseServer } from "./supabase/server";
import { verifiedUser } from "./supabase/claims";

export const CHILD_COOKIE = "kl_child";
export const GATE_COOKIE = "kl_gate";
export const GATE_MINUTES = 15;

export type Family = { userId: string; email: string; accountId: string; role: string; timezone: string; country: string | null; status: string };
export type Child = { id: string; nickname: string; birthYearMonth: string; avatarId: string | null; avatarKey: string | null; stage: string; status: string };

/** The signed-in parent, once per request (layout and page share it). The session token's
 * signature is verified against the project's keys, not just read from the cookie. */
export const currentUser = cache(async () => {
  const db = await supabaseServer();
  return { db, user: await verifiedUser(db) };
});

/** The signed-in parent's family, or null when the set-up (onboarding) isn't finished. */
export async function familyOf(db: Awaited<ReturnType<typeof supabaseServer>>, userId: string, email: string): Promise<Family | null> {
  const { data } = await db.from("parent_profiles")
    .select("account_id, role, parent_accounts(timezone, country, status)").eq("user_id", userId).maybeSingle();
  if (!data) return null;
  const acc = data.parent_accounts as unknown as { timezone: string; country: string | null; status: string } | null;
  return { userId, email, accountId: data.account_id, role: data.role, timezone: acc?.timezone ?? "UTC", country: acc?.country ?? null, status: acc?.status ?? "active" };
}

/** The parent and their family, loaded once per request however many times it's asked for. */
const loadFamily = cache(async () => {
  const { db, user } = await currentUser();
  return { db, user, family: user ? await familyOf(db, user.id, user.email ?? "") : null };
});

/** A parent with a family; else to sign-in (or to finish set-up). */
export async function requireFamily(next = "/") {
  const { db, user, family } = await loadFamily();
  if (!user) redirect(`/sign-in?next=${encodeURIComponent(next)}`);
  if (!family) redirect("/sign-up/family");
  return { db, user, family };
}

/** Grown-up pages: also behind the parental gate (a child holding the device can't wander in). */
export async function requireGrownUp(next: string) {
  const ctx = await requireFamily(next);
  const gate = Number((await cookies()).get(GATE_COOKIE)?.value ?? 0);
  if (!gate || gate < Date.now()) redirect(`/gate?next=${encodeURIComponent(next)}`);
  return ctx;
}

const childCols = "id, nickname, birth_year_month, avatar_id, learning_stage, status, avatars(key)";
export const childFrom = (r: Record<string, unknown>): Child => {
  const av = r.avatars as { key?: string } | null;
  return { id: r.id as string, nickname: r.nickname as string, birthYearMonth: String(r.birth_year_month ?? "").slice(0, 7), avatarId: (r.avatar_id as string) ?? null,
    avatarKey: av?.key ?? null, stage: r.learning_stage as string, status: r.status as string };
};

export async function listChildren(db: Awaited<ReturnType<typeof supabaseServer>>): Promise<Child[]> {
  const { data, error } = await db.from("child_profiles").select(childCols).eq("status", "active").order("sort").order("created_at");
  if (error) throw new Error(error.message);
  return (data ?? []).map(childFrom);
}

/** The child zone: the chosen child (from the cookie, checked against the parent's own children). */
export async function requireChild(next = "/kids") {
  const ctx = await requireFamily(next);
  const id = (await cookies()).get(CHILD_COOKIE)?.value;
  if (!id) redirect("/who");
  const { data } = await ctx.db.from("child_profiles").select(childCols).eq("id", id).eq("status", "active").maybeSingle();
  if (!data) redirect("/who");
  return { ...ctx, child: childFrom(data) };
}
