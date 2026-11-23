"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { callEdge } from "@/lib/edge";
import { requireChild } from "@/lib/session";

/** A child picks a new buddy (PATCH /children/:id — the same call the app makes from "Me"). */
export async function changeBuddy(fd: FormData) {
  const { child } = await requireChild("/kids/me");
  const avatarId = z.string().uuid().parse(fd.get("avatarId"));
  await callEdge(`children/${child.id}`, { method: "PATCH", body: { avatarId } });
  revalidatePath("/kids", "layout");
}
