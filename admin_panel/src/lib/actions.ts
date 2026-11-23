import "server-only";
import { ZodError } from "zod";
import { AdminError } from "./errors";
import { problems } from "./validation";

/** What a form action returns to the form (values come back so nothing typed is lost). */
export type FormResult = { ok?: string; error?: string; fieldErrors?: Record<string, string>; values?: Record<string, string> };

export const values = (fd: FormData) =>
  Object.fromEntries([...fd.entries()].filter(([, v]) => typeof v === "string") as [string, string][]);

/** Runs a form action: validation and database errors become messages on the form. */
export async function run(fd: FormData, fn: () => Promise<string | void>): Promise<FormResult> {
  try {
    const ok = await fn();
    return { ok: ok || "Saved", values: values(fd) };
  } catch (e) {
    if (e instanceof ZodError) {
      // a single value parsed on its own (a title, a reason) has no field path: say what's wrong
      const loose = e.issues.find((i) => i.path.length === 0);
      if (loose) return { error: loose.code === "too_small" ? "Fill this in first." : loose.message, values: values(fd) };
      return { error: "Check the highlighted fields.", fieldErrors: problems(e), values: values(fd) };
    }
    if (e instanceof AdminError) return { error: e.message, values: values(fd) };
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
