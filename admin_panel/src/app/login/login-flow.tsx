"use client";
// Email + password, then the authenticator code (aal2). An admin without an authenticator sets
// one up here first. Nothing is stored in the browser except Supabase's session cookie.
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabaseBrowser } from "@/lib/supabase/browser";

type Step = "password" | "code" | "enroll";
const input = "w-full rounded-md border border-ui-border-input bg-ui-bg px-s4 min-h-tap-ui text-ui-body";
const button = "min-h-tap-ui rounded-md bg-ui-primary px-s5 text-ui-body-strong text-ui-on-primary hover:bg-ui-primary-hover disabled:opacity-50";

export function LoginFlow({ startAtMfa }: { startAtMfa: boolean }) {
  const router = useRouter();
  const [step, setStep] = useState<Step>("password");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [factorId, setFactorId] = useState<string | null>(null);
  const [qr, setQr] = useState<{ svg: string; secret: string } | null>(null);
  const db = supabaseBrowser();

  async function afterPassword() {
    // Only staff go on to the authenticator step: a parent's account never enrols a factor here.
    // (The server decides again on every request; this just stops a dead end.)
    const { data: me } = await db.schema("admin_api").rpc("me");
    if (!me) {
      await db.auth.signOut();
      throw new Error("This account isn't an admin. Ask a super admin to add you.");
    }
    const { data: f } = await db.auth.mfa.listFactors();
    const totp = f?.totp?.find((x) => x.status === "verified");
    if (totp) {
      setFactorId(totp.id);
      setStep("code");
      return;
    }
    const { data, error } = await db.auth.mfa.enroll({ factorType: "totp", friendlyName: "Admin authenticator" });
    if (error || !data) throw new Error(error?.message ?? "Couldn't start the authenticator setup.");
    setFactorId(data.id);
    setQr({ svg: data.totp.qr_code, secret: data.totp.secret });
    setStep("enroll");
  }

  useEffect(() => {
    if (startAtMfa) afterPassword().catch(() => setStep("password"));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [startAtMfa]);

  async function onPassword(fd: FormData) {
    setBusy(true);
    setError(null);
    const { error } = await db.auth.signInWithPassword({ email: String(fd.get("email")), password: String(fd.get("password")) });
    if (error) {
      setError("That email and password don't match an account.");
      setBusy(false);
      return;
    }
    try {
      await afterPassword();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong.");
    }
    setBusy(false);
  }

  async function onCode(fd: FormData) {
    if (!factorId) return;
    setBusy(true);
    setError(null);
    const { error } = await db.auth.mfa.challengeAndVerify({ factorId, code: String(fd.get("code")).replace(/\s/g, "") });
    if (error) {
      setError("That code didn't work. Codes change every 30 seconds; try the current one.");
      setBusy(false);
      return;
    }
    router.replace("/");
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-s5">
      {error && <p role="alert" className="rounded-md bg-ui-danger-soft p-s4 text-ui-danger">{error}</p>}
      {step === "password" && (
        <form action={onPassword} className="flex flex-col gap-s5">
          <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">Email</span>
            <input name="email" type="email" autoComplete="username" required className={input} /></label>
          <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">Password</span>
            <input name="password" type="password" autoComplete="current-password" required className={input} /></label>
          <button disabled={busy} className={button}>{busy ? "Signing in…" : "Continue"}</button>
        </form>
      )}
      {step === "enroll" && qr && (
        <div className="flex flex-col gap-s4">
          <h2 className="text-ui-h3">Set up your authenticator</h2>
          <p className="text-ui-body">Scan this with an authenticator app, then type the 6-digit code it shows.</p>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={qr.svg} alt="QR code for the authenticator app" className="size-ui-sidebar-w" />
          <p className="text-ui-small text-ui-text-muted">Or enter this key by hand: <code className="font-mono">{qr.secret}</code></p>
        </div>
      )}
      {(step === "code" || step === "enroll") && (
        <form action={onCode} className="flex flex-col gap-s5">
          <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">6-digit code</span>
            <input name="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,7}" required className={input} /></label>
          <button disabled={busy} className={button}>{busy ? "Checking…" : "Sign in"}</button>
        </form>
      )}
    </div>
  );
}
