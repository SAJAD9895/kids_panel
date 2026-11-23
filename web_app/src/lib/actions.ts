import "server-only";
import { ZodError } from "zod";
import { FormError } from "./form-error";

/** Zod issues → { field: message } (first message per field). */
export function problems(e: ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const i of e.issues) { const k = String(i.path[0] ?? ""); if (k && !out[k]) out[k] = i.message; }
  return out;
}

/** What a form action returns to the form (values come back so nothing typed is lost). */
export type FormResult = { ok?: string; error?: string; fieldErrors?: Record<string, string>; values?: Record<string, string> };

/** What was typed, to put back in the form after an error — never passwords or codes. */
export const values = (fd: FormData) =>
  Object.fromEntries([...fd.entries()].filter(([k, v]) => typeof v === "string" && !/password|confirm|code/i.test(k)) as [string, string][]);

/** Runs a form action: validation and database errors become messages on the form. */
export async function run(fd: FormData, fn: () => Promise<string | void>): Promise<FormResult> {
  try {
    const ok = await fn();
    return { ok: ok || "Saved", values: values(fd) };
  } catch (e) {
    if (e instanceof ZodError) {
      // a single value parsed on its own (a title, a reason) has no field path: say what's wrong
      const loose = e.issues.find((i) => i.path.length === 0);
      if (loose) return { error: /^String must contain|^Required$/.test(loose.message) ? "Fill this in first." : loose.message, values: values(fd) };
      return { error: "Check the highlighted fields.", fieldErrors: problems(e), values: values(fd) };
    }
    if (e instanceof FormError) return { error: e.message, values: values(fd) };
    if (e && typeof e === "object" && "digest" in e && String((e as { digest: string }).digest).startsWith("NEXT_REDIRECT")) throw e;
    console.error(e);
    return { error: e instanceof Error ? e.message : "Something went wrong. Try again.", values: values(fd) };
  }
}

/** For plain (non-form) actions that should report failures without throwing. */
export async function attempt<T>(fn: () => Promise<T>): Promise<{ ok: true; value: T } | { ok: false; error: string }> {
  try {
    return { ok: true, value: await fn() };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : "Something went wrong." };
  }
}
