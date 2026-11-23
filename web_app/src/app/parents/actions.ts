"use server";
// Grown-up actions. Each goes through the same Edge Function as the app, with the parent's
// session; the server checks the household, the plan and (for deletions and exports) a recent
// sign-in. REAUTH_REQUIRED sends the parent to sign in again and back.
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { run, values, type FormResult } from "@/lib/actions";
import { callEdge, EdgeError } from "@/lib/edge";
import { sayError } from "@/lib/errors";
import { FormError } from "@/lib/form-error";
import { requireGrownUp } from "@/lib/session";
import { strongPassword } from "@/lib/validation";
import { supabaseServer } from "@/lib/supabase/server";

async function edge<T>(path: string, init: { method?: string; body?: unknown }, back: string): Promise<T> {
  try {
    return await callEdge<T>(path, init);
  } catch (e) {
    if (e instanceof EdgeError && e.type === "REAUTH_REQUIRED") redirect(`/sign-in?next=${encodeURIComponent(back)}&reauth=1`);
    if (e instanceof EdgeError) throw new FormError(sayError(e.type, e.detail));
    throw e;
  }
}
const nickname = z.string().trim().min(1, "Give a name or nickname").max(20, "Up to 20 letters");
const birth = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, "Choose the month and year");

export async function addChild(_: FormResult, fd: FormData): Promise<FormResult> {
  let id = "";
  const r = await run(fd, async () => {
    await requireGrownUp("/parents/children/new");
    const v = values(fd);
    const c = await edge<{ childId: string }>("children", { body: { nickname: nickname.parse(v.nickname), birthYearMonth: birth.parse(v.birthYearMonth), avatarId: v.avatarId || undefined } }, "/parents/children/new");
    id = c.childId;
  });
  if (id) { revalidatePath("/parents", "layout"); redirect(`/parents/children/${id}?added=1`); }
  return r;
}

export async function editChild(childId: string, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp(`/parents/children/${childId}`);
    const v = values(fd);
    await edge(`children/${childId}`, { method: "PATCH", body: { nickname: nickname.parse(v.nickname), birthYearMonth: birth.parse(v.birthYearMonth), avatarId: v.avatarId || null } }, `/parents/children/${childId}`);
    revalidatePath("/parents", "layout");
    return "Saved";
  });
}

export async function deleteChild(childId: string, _: FormResult, fd: FormData): Promise<FormResult> {
  let ok = false;
  const r = await run(fd, async () => {
    await requireGrownUp(`/parents/children/${childId}`);
    await edge(`children/${childId}`, { method: "DELETE" }, `/parents/children/${childId}`);
    ok = true;
  });
  if (ok) { revalidatePath("/parents", "layout"); redirect("/parents/children?deleted=1"); }
  return r;
}

export async function saveControls(childId: string, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp(`/parents/children/${childId}/controls`);
    const limit = String(fd.get("limit") ?? "");
    const allCats = fd.getAll("allCategories").map(String);
    const on = new Set(fd.getAll("category").map(String));
    await edge(`children/${childId}/screen-time`, { method: "PUT", body: {
      learnEnabled: fd.get("learn") === "on", watchEnabled: fd.get("watch") === "on", listenEnabled: fd.get("listen") === "on", togetherEnabled: fd.get("together") === "on",
      dailyLimitMinutes: limit ? z.coerce.number().int().min(5).max(600).parse(limit) : null,
      limitedSections: fd.getAll("limited").map(String).filter((x) => ["learn", "watch", "listen", "together"].includes(x)),
      blockedCategoryIds: allCats.filter((c) => !on.has(c)),
    } }, `/parents/children/${childId}/controls`);
    revalidatePath(`/parents/children/${childId}/controls`);
    return "Saved. The child's next launch follows these settings.";
  });
}

export async function saveGoals(childId: string, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp(`/parents/children/${childId}/rewards`);
    await edge(`children/${childId}/goals`, { method: "PUT", body: {
      enabled: fd.get("enabled") === "on",
      dailyActivities: z.coerce.number().int().min(1).max(10).parse(fd.get("daily")),
      weeklyDays: z.coerce.number().int().min(1).max(7).parse(fd.get("weekly")),
    } }, `/parents/children/${childId}/rewards`);
    revalidatePath(`/parents/children/${childId}/rewards`);
    return "Goals saved";
  });
}

export async function markAllRead(_: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp("/parents/notifications");
    await edge("account/notifications/read", { body: {} }, "/parents/notifications");
    revalidatePath("/parents", "layout");
    return "All marked as read";
  });
}

export async function savePreferences(types: string[], _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp("/parents/notifications");
    await edge("account/notification-preferences", { method: "PUT", body: types.map((type) => ({ type, channel: "in_app", enabled: fd.get(type) === "on" })) }, "/parents/notifications");
    revalidatePath("/parents/notifications");
    return "Preferences saved";
  });
}

export async function requestExport(_: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp("/parents/privacy");
    const childId = String(fd.get("childId") ?? "");
    await edge("account/export", { body: childId ? { childId } : {} }, "/parents/privacy");
    revalidatePath("/parents/privacy");
    return "Your export is ready below. Downloads last an hour; the file is kept 7 days.";
  });
}

export async function downloadExport(id: string) {
  await requireGrownUp("/parents/privacy");
  const r = await edge<{ url: string }>(`account/exports/${id}/url`, {}, "/parents/privacy");
  redirect(r.url);
}

export async function scheduleDeletion(_: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp("/parents/privacy");
    if (String(fd.get("confirm") ?? "").trim().toUpperCase() !== "DELETE") throw new FormError("Type DELETE to confirm.");
    await edge("account/deletion", { body: {} }, "/parents/privacy");
    revalidatePath("/parents/privacy");
    return "Your account will be deleted in 7 days. You can keep it until then.";
  });
}

export async function cancelDeletion(id: string, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp("/parents/privacy");
    await edge(`account/deletion/${id}`, { method: "DELETE" }, "/parents/privacy");
    revalidatePath("/parents/privacy");
    return "Your account is kept.";
  });
}

export async function changePassword(_: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    await requireGrownUp("/parents/settings");
    const p = strongPassword.parse(fd.get("password"));
    if (p !== fd.get("confirm")) throw new FormError("The two passwords are different.");
    const db = await supabaseServer();
    const { error } = await db.auth.updateUser({ password: p });
    if (error) throw new FormError(error.message);
    return "Password changed";
  });
}
