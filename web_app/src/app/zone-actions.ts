"use server";
// Moving between the child zone and the grown-up pages.
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { CHILD_COOKIE, GATE_COOKIE, GATE_MINUTES, requireFamily } from "@/lib/session";

const opts = { httpOnly: true, sameSite: "lax" as const, secure: process.env.NODE_ENV === "production", path: "/" };

/** A child is chosen: remember them (a year) and lock the grown-up pages again. */
export async function chooseChild(childId: string) {
  const { db } = await requireFamily("/who");
  // RLS: only the parent's own children are visible, so another family's id finds nothing.
  const { data } = await db.from("child_profiles").select("id").eq("id", childId).eq("status", "active").maybeSingle();
  if (!data) redirect("/who");
  const jar = await cookies();
  jar.set(CHILD_COOKIE, childId, { ...opts, maxAge: 365 * 86400 });
  jar.delete(GATE_COOKIE);
  redirect("/kids");
}

/** The grown-up answered the gate question. (The gate keeps young children out of the grown-up
 * pages; the parent's own session is what protects the data.) */
export async function passGate(next: string) {
  await requireFamily("/gate");
  (await cookies()).set(GATE_COOKIE, String(Date.now() + GATE_MINUTES * 60_000), { ...opts, maxAge: GATE_MINUTES * 60 });
  redirect(next.startsWith("/parents") ? next : "/parents");
}

/** From the grown-up pages back to the child zone: the gate closes. */
export async function backToKids() {
  (await cookies()).delete(GATE_COOKIE);
  redirect("/who");
}
