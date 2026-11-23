import Link from "next/link";
import { notFound } from "next/navigation";
import { requireAdmin } from "@/lib/auth";
import { getCourse, listCategories, listSubjects, validateContent } from "@/lib/data/content";
import { listAssets } from "@/lib/data/media";
import { AdminError } from "@/lib/errors";
import { canAny } from "@/lib/permissions";
import { CourseForm } from "@/components/course-forms";
import { ActionForm, ConfirmAction, Submit, TextField } from "@/components/form";
import { Workflow } from "@/components/workflow";
import { Card, Notice, PageHeader, StatusBadge } from "@/components/ui";
import { moveStatus } from "../../activities/actions";
import { addLesson, addModule, moveLesson, moveModule, removeCourse, removeModule, renameModule, updateCourse } from "../actions";

const small = "min-h-tap-ui rounded-md border border-ui-border-input bg-ui-bg px-s3 text-ui-small hover:bg-ui-surface";

export default async function CoursePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ created?: string }> }) {
  const { id } = await params;
  const { created } = await searchParams;
  const { admin, db } = await requireAdmin(["content.read"]);
  const c = await getCourse(db, id).catch((e) => { if (e instanceof AdminError) notFound(); throw e; });
  const [s, cats, imgs, problems] = await Promise.all([listSubjects(db), listCategories(db), listAssets(db, { kind: "image", status: "ready", pageSize: 200 }), validateContent(db, "courses", id)]);
  const p = admin.permissions;
  const editable = canAny(p, ["content.write"]) && c.status !== "in_review" && (!["approved", "published"].includes(c.status) || canAny(p, ["content.publish"]));
  return (
    <>
      <PageHeader title={c.title || c.slug} back={{ href: "/content/courses", label: "Courses" }} subtitle={<StatusBadge status={c.status} />} />
      <div className="flex flex-col gap-s6">
        {created && <Notice tone="success">Course created. Add modules and lessons below.</Notice>}
        <Card title="Publishing"><Workflow table="courses" id={c.id} status={c.status} permissions={p} problems={problems} action={moveStatus} /></Card>
        <Card title="Course details">
          <CourseForm action={updateCourse.bind(null, c.id)} c={c} canWrite={editable} subjects={s.map((x) => ({ value: x.id, label: x.name }))}
            categories={cats.map((x) => ({ value: x.id, label: x.name }))} images={imgs.rows.map((x) => ({ value: x.id, label: x.path }))} />
        </Card>
        <Card title="Modules and lessons">
          {c.modules.length === 0 && <p className="mb-s4 text-ui-body text-ui-text-muted">No modules yet. A module groups lessons (for example “Letters a–h”).</p>}
          <ol className="flex flex-col gap-s5">
            {c.modules.map((m, mi) => (
              <li key={m.id} className="rounded-lg border border-ui-border p-s5">
                <div className="flex flex-wrap items-end justify-between gap-s3">
                  {editable ? (
                    <ActionForm action={renameModule.bind(null, c.id, m.id)} className="!flex-row items-end">
                      <TextField name="title" label={`Module ${mi + 1}`} initial={m.title} />
                      <Submit variant="secondary">Rename</Submit>
                    </ActionForm>
                  ) : <h3 className="text-ui-h3">Module {mi + 1}: {m.title}</h3>}
                  {editable && (
                    <div className="flex gap-s2">
                      <form action={moveModule.bind(null, c.id, m.id, -1)}><button className={small} aria-label={`Move module ${mi + 1} up`}>↑</button></form>
                      <form action={moveModule.bind(null, c.id, m.id, 1)}><button className={small} aria-label={`Move module ${mi + 1} down`}>↓</button></form>
                      <ConfirmAction action={removeModule.bind(null, c.id, m.id)} label="Remove module" title="Remove this module?" message="Its lessons and steps are removed too." confirm="Remove" danger />
                    </div>
                  )}
                </div>
                <ol className="mt-s4 flex flex-col gap-s2">
                  {m.lessons.map((l, li) => (
                    <li key={l.id} className="flex flex-wrap items-center justify-between gap-s3 rounded-md bg-ui-surface p-s3">
                      <Link href={`/content/courses/${c.id}/lessons/${l.id}`} className="text-ui-primary hover:underline">Lesson {li + 1}: {l.title}</Link>
                      <span className="flex items-center gap-s3 text-ui-small text-ui-text-muted">
                        {l.steps.length} activit{l.steps.length === 1 ? "y" : "ies"}{l.estimatedMinutes ? ` · ${l.estimatedMinutes} min` : ""}{l.prerequisites.length ? ` · ${l.prerequisites.length} prerequisite(s)` : ""}
                        {editable && <>
                          <form action={moveLesson.bind(null, c.id, l.id, -1)}><button className={small} aria-label={`Move lesson ${li + 1} up`}>↑</button></form>
                          <form action={moveLesson.bind(null, c.id, l.id, 1)}><button className={small} aria-label={`Move lesson ${li + 1} down`}>↓</button></form>
                        </>}
                      </span>
                    </li>
                  ))}
                </ol>
                {editable && (
                  <ActionForm action={addLesson.bind(null, c.id, m.id)} className="mt-s4 !flex-row items-end">
                    <TextField name="title" label="New lesson" />
                    <Submit variant="secondary">Add lesson</Submit>
                  </ActionForm>
                )}
              </li>
            ))}
          </ol>
          {editable && (
            <ActionForm action={addModule.bind(null, c.id)} className="mt-s5 !flex-row items-end" resetOnOk>
              <TextField name="title" label="New module" />
              <Submit variant="secondary">Add module</Submit>
            </ActionForm>
          )}
        </Card>
        {editable && c.status === "draft" && (
          <Card title="Delete">
            <ConfirmAction action={removeCourse.bind(null, c.id)} label="Delete this draft course" danger title="Delete this course?" message="Modules, lessons and steps go with it. Activities stay." confirm="Delete" />
          </Card>
        )}
      </div>
    </>
  );
}
