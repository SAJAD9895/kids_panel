"use server";
import { revalidatePath } from "next/cache";
import { run, values, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import * as c from "@/lib/data/content";
import { categoryInput, subjectInput } from "@/lib/validation";

const write = async () => (await requireAdmin(["content.write"])).db;
const done = () => revalidatePath("/content/taxonomy");

export async function saveSubject(id: string | undefined, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.saveSubject(await write(), subjectInput.parse(values(fd)), id); done(); return id ? "Subject saved" : "Subject added"; });
}
export async function removeSubject(id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.deleteSubject(await write(), id); done(); return "Subject deleted"; });
}
export async function saveCategory(id: string | undefined, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.saveCategory(await write(), categoryInput.parse(values(fd)), id); done(); return id ? "Category saved" : "Category added"; });
}
export async function toggleCategory(id: string, enable: boolean, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.setCategoryEnabled(await write(), id, enable); done(); return enable ? "Category enabled" : "Category disabled"; });
}
export async function removeCategory(id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.deleteCategory(await write(), id); done(); return "Category deleted"; });
}
