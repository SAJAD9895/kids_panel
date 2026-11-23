"use server";
import { revalidatePath } from "next/cache";
import { run, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import { callEdge } from "@/lib/edge";
import { setAssetLocale, setAssetStatus } from "@/lib/data/media";

export async function finalizeUpload(v: { stagingPath: string; locale?: string; width?: number; height?: number; durationMs?: number }) {
  try {
    await requireAdmin(["content.write"]);
    const asset = await callEdge<{ id: string; path: string }>("admin/media/finalize", v);
    revalidatePath("/media");
    return { asset };
  } catch (e) {
    return { error: e instanceof Error ? e.message : "The upload couldn't be finished." };
  }
}
export async function retireAsset(id: string, retire: boolean, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    await setAssetStatus(db, id, retire ? "retired" : "ready");
    revalidatePath("/media");
    return retire ? "File retired" : "File restored";
  });
}
export async function saveLocale(id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["content.write"]);
    await setAssetLocale(db, id, String(fd.get("locale") ?? "").trim() || null);
    revalidatePath("/media");
  });
}
