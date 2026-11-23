"use server";
import { revalidatePath } from "next/cache";
import { run, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import { callEdge } from "@/lib/edge";

export async function runExport(id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    await requireAdmin(["privacy.act"]);
    await callEdge(`admin/exports/${id}/run`, {});
    revalidatePath("/privacy");
    return "Export built; the parent was notified";
  });
}
