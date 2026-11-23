"use server";
import { revalidatePath } from "next/cache";
import { run, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import { cancelDeletion, grantStars, setAccountStatus } from "@/lib/data/people";
import { AdminError } from "@/lib/errors";

export async function restrict(accountId: string, status: "active" | "suspended", _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["support.act"]);
    await setAccountStatus(db, accountId, status, String(fd.get("reason") ?? ""));
    revalidatePath(`/families/${accountId}`);
    return status === "suspended" ? "Account suspended" : "Account active again";
  });
}
export async function cancelDel(accountId: string, requestId: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["support.act"]);
    await cancelDeletion(db, requestId, String(fd.get("reason") ?? ""));
    revalidatePath(`/families/${accountId}`);
    return "Deletion cancelled";
  });
}
export async function addStars(accountId: string, childId: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const { db } = await requireAdmin(["support.act"]);
    const amount = Number(fd.get("amount"));
    if (!Number.isInteger(amount)) throw new AdminError("Give a whole number of stars.");
    const r = await grantStars(db, childId, amount, String(fd.get("reason") ?? ""), String(fd.get("requestId")));
    revalidatePath(`/families/${accountId}`);
    return r.granted ? `Added. Balance: ${r.balance}` : "Already added (this request was used)";
  });
}
