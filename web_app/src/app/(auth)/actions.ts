"use server";
// Parent authentication. Everything runs on the server with @supabase/ssr, which keeps the session
// in cookies; no token is handled by page scripts. Email codes are the sign-up and sign-in method
// (as in the app: docs/backend/authentication.md); a password is optional and can be reset by code.
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { run, type FormResult } from "@/lib/actions";
import { callEdge, EdgeError } from "@/lib/edge";
import { sayError } from "@/lib/errors";
import { CHILD_COOKIE, GATE_COOKIE, GATE_MINUTES } from "@/lib/session";
import { supabaseServer } from "@/lib/supabase/server";
import { FormError } from "@/lib/form-error";
import { POLICY_VERSION, strongPassword } from "@/lib/validation";

const email = z.string().trim().toLowerCase().email("Enter an email address");
const code = z.string().trim().regex(/^\d{6}$/, "The code has 6 digits");
/** Only local paths after sign-in (no open redirect to another site). */
const safeNext = (n: FormDataEntryValue | null) => {
  const s = String(n ?? "");
  return s.startsWith("/") && !s.startsWith("//") ? s : "/who";
};
/** A parent who just proved who they are is the grown-up: open the gate for a while. */
async function openGate() {
  (await cookies()).set(GATE_COOKIE, String(Date.now() + GATE_MINUTES * 60_000), { httpOnly: true, sameSite: "lax", secure: process.env.NODE_ENV === "production", path: "/", maxAge: GATE_MINUTES * 60 });
}
/** Where an emailed magic link lands: this site's /auth/callback (it must be in the Supabase
 * Redirect URLs allow-list, otherwise Supabase falls back to the project's Site URL). */
async function callbackUrl(next: string) {
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host");
  const proto = h.get("x-forwarded-proto") ?? (host?.startsWith("localhost") ? "http" : "https");
  return `${proto}://${host}/auth/callback?next=${encodeURIComponent(next)}`;
}
const authWords = (msg: string) =>
  /invalid login/i.test(msg) ? "That email and password don't match." : /expired|invalid/i.test(msg) ? "That code is wrong or has expired. Ask for a new one." : /rate|too many/i.test(msg) ? "Too many tries. Please wait a minute." : msg;

export async function signInWithPassword(_: FormResult, fd: FormData): Promise<FormResult> {
  let ok = false;
  const r = await run(fd, async () => {
    const db = await supabaseServer();
    const { error } = await db.auth.signInWithPassword({ email: email.parse(fd.get("email")), password: String(fd.get("password") ?? "") });
    if (error) throw new FormError(authWords(error.message));
    await openGate();
    ok = true;
  });
  if (ok) redirect(safeNext(fd.get("next")));
  return r;
}

/** Sends a 6-digit code. Sign-in never creates an account; sign-up does. */
export async function sendCode(purpose: "sign-in" | "sign-up", _: FormResult, fd: FormData): Promise<FormResult> {
  let to = "";
  const r = await run(fd, async () => {
    const e = email.parse(fd.get("email"));
    const db = await supabaseServer();
    const emailRedirectTo = await callbackUrl(purpose === "sign-up" ? "/sign-up/family" : safeNext(fd.get("next")));
    const { error } = await db.auth.signInWithOtp({ email: e, options: { shouldCreateUser: purpose === "sign-up", emailRedirectTo } });
    // Don't reveal whether an address has an account: a sign-in code request always "succeeds".
    if (error && purpose === "sign-up") throw new FormError(authWords(error.message));
    to = e;
  });
  if (to) redirect(`${purpose === "sign-up" ? "/sign-up/verify" : "/sign-in/code"}?email=${encodeURIComponent(to)}&next=${encodeURIComponent(safeNext(fd.get("next")))}`);
  return r;
}

export async function verifyCode(purpose: "sign-in" | "sign-up", _: FormResult, fd: FormData): Promise<FormResult> {
  let done = false;
  const r = await run(fd, async () => {
    const db = await supabaseServer();
    const { error } = await db.auth.verifyOtp({ email: email.parse(fd.get("email")), token: code.parse(fd.get("code")), type: "email" });
    if (error) throw new FormError(authWords(error.message));
    await openGate();
    done = true;
  });
  if (done) redirect(purpose === "sign-up" ? "/sign-up/family" : safeNext(fd.get("next")));
  return r;
}

const family = z.object({
  nickname: z.string().trim().min(1, "Give a name or nickname").max(20, "Up to 20 letters"),
  birthYearMonth: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, "Choose the month and year"),
  avatarId: z.string().uuid().optional().or(z.literal("").transform(() => undefined)),
  timezone: z.string().min(1).max(64),
  country: z.string().regex(/^[A-Z]{2}$/).optional().or(z.literal("").transform(() => undefined)),
  terms: z.literal("on", { errorMap: () => ({ message: "Please accept the terms" }) }),
  privacy: z.literal("on", { errorMap: () => ({ message: "Please accept the privacy policy" }) }),
  childData: z.literal("on", { errorMap: () => ({ message: "We need your consent to save your child's progress" }) }),
  marketing: z.string().optional(),
});

/** Creates the family: account, the grown-up's profile, consents and the first child, in one go
 * (POST /onboarding/complete → private.onboard_family). */
export async function createFamily(_: FormResult, fd: FormData): Promise<FormResult> {
  let ok = false;
  const r = await run(fd, async () => {
    const v = family.parse(Object.fromEntries(fd.entries()));
    const consents = [
      { type: "terms", policyVersion: POLICY_VERSION, method: "checkbox" },
      { type: "privacy_policy", policyVersion: POLICY_VERSION, method: "checkbox" },
      { type: "child_data_collection", policyVersion: POLICY_VERSION, method: "email_plus" },
      ...(v.marketing === "on" ? [{ type: "marketing", policyVersion: POLICY_VERSION, method: "checkbox" }] : []),
    ];
    try {
      await callEdge("onboarding/complete", { body: { timezone: v.timezone, country: v.country, uiLocale: "en", contentLocale: "en", marketingOptIn: v.marketing === "on",
        child: { nickname: v.nickname, birthYearMonth: v.birthYearMonth, avatarId: v.avatarId }, consents } });
    } catch (e) {
      if (e instanceof EdgeError) throw new FormError(sayError(e.type, e.detail));
      throw e;
    }
    ok = true;
  });
  if (ok) redirect("/sign-up/password");
  return r;
}

export async function setPassword(_: FormResult, fd: FormData): Promise<FormResult> {
  let ok = false;
  const r = await run(fd, async () => {
    const p = strongPassword.parse(fd.get("password"));
    if (p !== fd.get("confirm")) throw new FormError("The two passwords are different.");
    const db = await supabaseServer();
    const { error } = await db.auth.updateUser({ password: p });
    if (error) throw new FormError(error.message);
    ok = true;
  });
  if (ok) redirect(safeNext(fd.get("next")));
  return r;
}

export async function sendRecovery(_: FormResult, fd: FormData): Promise<FormResult> {
  let to = "";
  const r = await run(fd, async () => {
    const e = email.parse(fd.get("email"));
    const db = await supabaseServer();
    await db.auth.resetPasswordForEmail(e); // same answer whether or not the address has an account
    to = e;
  });
  if (to) redirect(`/forgot-password/verify?email=${encodeURIComponent(to)}`);
  return r;
}

export async function resetPassword(_: FormResult, fd: FormData): Promise<FormResult> {
  let ok = false;
  const r = await run(fd, async () => {
    const p = strongPassword.parse(fd.get("password"));
    const db = await supabaseServer();
    const { error } = await db.auth.verifyOtp({ email: email.parse(fd.get("email")), token: code.parse(fd.get("code")), type: "recovery" });
    if (error) throw new FormError(authWords(error.message));
    const u = await db.auth.updateUser({ password: p });
    if (u.error) throw new FormError(u.error.message);
    await openGate();
    ok = true;
  });
  if (ok) redirect("/who");
  return r;
}

/** Secure sign-out: ends the session (everywhere when asked) and forgets the child and the gate. */
export async function signOut(fd: FormData) {
  const db = await supabaseServer();
  await db.auth.signOut({ scope: fd.get("everywhere") === "on" ? "global" : "local" });
  const jar = await cookies();
  jar.delete(CHILD_COOKIE);
  jar.delete(GATE_COOKIE);
  redirect("/sign-in?signedOut=1");
}
