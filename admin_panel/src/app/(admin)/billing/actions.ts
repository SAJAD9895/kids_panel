"use server";
import { revalidatePath } from "next/cache";
import { run, values, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import { savePlan } from "@/lib/data/business";

export async function savePlanAction(id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["billing.manage"]);
    const v = values(fd);
    await savePlan(db, id, { trialDays: Number(v.trialDays), maxChildren: Number(v.maxChildren), active: v.active === "on", apple: v.apple ?? "", google: v.google ?? "", stripe: v.stripe ?? "" });
    revalidatePath("/billing");
    return "Plan saved";
  });
}
