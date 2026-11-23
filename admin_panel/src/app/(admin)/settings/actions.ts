"use server";
import { revalidatePath } from "next/cache";
import { run, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import { saveSetting, setAdminStatus, setRoles } from "@/lib/data/admin";

export async function saveRoles(_: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["admin.manage"]);
    await setRoles(db, String(fd.get("email") ?? ""), fd.getAll("roles").map(String));
    revalidatePath("/settings/admins");
    return "Roles saved";
  });
}
export async function adminStatus(userId: string, status: "active" | "suspended", _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["admin.manage"]);
    await setAdminStatus(db, userId, status);
    revalidatePath("/settings/admins");
    return status === "suspended" ? "Admin suspended" : "Admin active";
  });
}
export async function saveSettingAction(key: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["admin.manage"]);
    await saveSetting(db, key, String(fd.get("value") ?? ""));
    revalidatePath("/settings/system");
  });
}
