"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { run, values, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import { deleteActivity, saveActivity, transition } from "@/lib/data/content";
import { attach, detach } from "@/lib/data/media";
import { deleteQuestion, saveGameConfig, saveQuestion, type QuestionInput } from "@/lib/data/games";
import type { GameConfig } from "@/lib/game/config";
import { activityInput, transitionInput } from "@/lib/validation";

export async function createActivity(_: FormResult, fd: FormData): Promise<FormResult> {
  let id: string | undefined;
  const r = await run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    id = (await saveActivity(db, activityInput.parse(values(fd)))).id;
  });
  if (id) redirect(`/content/activities/${id}?created=1`);
  return r;
}

export async function updateActivity(id: string, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    await saveActivity(db, activityInput.parse({ type: "game", ...values(fd) }), id);
    revalidatePath(`/content/activities/${id}`);
  });
}

export async function removeActivity(id: string, _: FormResult, fd: FormData): Promise<FormResult> {
  const r = await run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    await deleteActivity(db, id);
  });
  if (!r.error) redirect("/content/activities");
  return r;
}

export async function moveStatus(_: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.read"]);
    const v = transitionInput.parse({ ...values(fd), note: fd.get("reason") ?? fd.get("note") ?? undefined });
    await transition(db, v.table, v.id, v.to, v.note);
    revalidatePath(v.table === "courses" ? `/content/courses/${v.id}` : `/content/activities/${v.id}`);
    revalidatePath("/content/review");
    return "Status changed";
  });
}

export async function saveConfig(id: string, config: GameConfig): Promise<{ error?: string }> {
  try {
    const { db } = await requireAdmin(["content.write"]);
    await saveGameConfig(db, id, config);
    revalidatePath(`/content/activities/${id}`);
    return {};
  } catch (e) {
    return { error: e instanceof Error ? e.message : "Couldn't save." };
  }
}

export async function saveQuizQuestion(activityId: string, q: QuestionInput, questionId?: string): Promise<{ error?: string }> {
  try {
    const { db } = await requireAdmin(["content.write"]);
    await saveQuestion(db, activityId, q, questionId);
    revalidatePath(`/content/activities/${activityId}`);
    return {};
  } catch (e) {
    return { error: e instanceof Error ? e.message : "Couldn't save." };
  }
}
export async function removeQuestion(activityId: string, questionId: string, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    await deleteQuestion(db, questionId);
    revalidatePath(`/content/activities/${activityId}`);
    return "Question removed";
  });
}

export async function attachMedia(activityId: string, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    const v = values(fd);
    await attach(db, activityId, { role: v.role, assetId: v.assetId, locale: v.locale, position: Number(v.position) || 0, text: v.text });
    revalidatePath(`/content/activities/${activityId}`);
    return "File attached";
  });
}
export async function detachMedia(activityId: string, role: string, locale: string, position: number, _: FormResult, fd: FormData): Promise<FormResult> {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    await detach(db, activityId, role, locale, position);
    revalidatePath(`/content/activities/${activityId}`);
    return "File removed";
  });
}
