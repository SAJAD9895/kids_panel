"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { run, values, type FormResult } from "@/lib/actions";
import { requireAdmin } from "@/lib/auth";
import * as c from "@/lib/data/content";
import { AdminError } from "@/lib/errors";
import { courseInput, lessonInput, STEP_TYPES, text, uuid } from "@/lib/validation";

const write = async () => (await requireAdmin(["content.write"])).db;
const done = (id: string) => revalidatePath(`/content/courses/${id}`);

export async function createCourse(_: FormResult, fd: FormData): Promise<FormResult> {
  let id: string | undefined;
  const r = await run(fd, async () => { id = (await c.saveCourse(await write(), courseInput.parse(values(fd)))).id; });
  if (id) redirect(`/content/courses/${id}?created=1`);
  return r;
}
export async function updateCourse(id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.saveCourse(await write(), courseInput.parse(values(fd)), id); done(id); });
}
export async function removeCourse(id: string, _: FormResult, fd: FormData) {
  const r = await run(fd, async () => { await c.deleteCourse(await write(), id); });
  if (!r.error) redirect("/content/courses");
  return r;
}
export async function addModule(courseId: string, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.addModule(await write(), courseId, text(80).parse(fd.get("title"))); done(courseId); return "Module added"; });
}
export async function renameModule(courseId: string, id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.renameModule(await write(), id, text(80).parse(fd.get("title"))); done(courseId); });
}
export async function removeModule(courseId: string, id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => { await c.deleteModule(await write(), id); done(courseId); return "Module removed"; });
}
export async function moveModule(courseId: string, id: string, dir: -1 | 1) {
  await c.moveModule(await write(), id, dir); done(courseId);
}
export async function addLesson(courseId: string, moduleId: string, _: FormResult, fd: FormData) {
  let lessonId: string | undefined;
  const r = await run(fd, async () => { lessonId = (await c.addLesson(await write(), moduleId, text(80).parse(fd.get("title")))).id; done(courseId); });
  if (lessonId) redirect(`/content/courses/${courseId}/lessons/${lessonId}`);
  return r;
}
export async function moveLesson(courseId: string, id: string, dir: -1 | 1) {
  await c.moveLesson(await write(), id, dir); done(courseId);
}
export async function updateLesson(courseId: string, id: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const v = lessonInput.parse({ ...values(fd), prerequisites: fd.getAll("prerequisites").map(String) });
    await c.saveLesson(await write(), id, v);
    revalidatePath(`/content/courses/${courseId}/lessons/${id}`); done(courseId);
  });
}
export async function removeLesson(courseId: string, id: string, _: FormResult, fd: FormData) {
  const r = await run(fd, async () => { await c.deleteLesson(await write(), id); done(courseId); });
  if (!r.error) redirect(`/content/courses/${courseId}`);
  return r;
}
export async function addStep(courseId: string, lessonId: string, _: FormResult, fd: FormData) {
  return run(fd, async () => {
    const type = String(fd.get("type"));
    if (!(STEP_TYPES as readonly string[]).includes(type)) throw new AdminError("Choose the step type.");
    await c.addStep(await write(), lessonId, uuid.parse(fd.get("activityId")), type, fd.get("required") === "on");
    revalidatePath(`/content/courses/${courseId}/lessons/${lessonId}`);
    return "Activity added";
  });
}
export async function stepAction(courseId: string, lessonId: string, id: string, op: "up" | "down" | "required" | "optional" | "remove") {
  const db = await write();
  if (op === "up" || op === "down") await c.moveStep(db, id, op === "up" ? -1 : 1);
  else if (op === "remove") await c.deleteStep(db, id);
  else await c.setStepRequired(db, id, op === "required");
  revalidatePath(`/content/courses/${courseId}/lessons/${lessonId}`);
}
