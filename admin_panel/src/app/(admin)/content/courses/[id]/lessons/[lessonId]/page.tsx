import Link from "next/link";
import { notFound } from "next/navigation";
import { requireAdmin } from "@/lib/auth";
import { getCourse, listActivities } from "@/lib/data/content";
import { listAssets } from "@/lib/data/media";
import { canAny } from "@/lib/permissions";
import { STEP_TYPES } from "@/lib/validation";
import { LessonForm } from "@/components/course-forms";
import { ActionForm, CheckField, ConfirmAction, SelectField, Submit } from "@/components/form";
import { Card, PageHeader, StatusBadge, Table } from "@/components/ui";
import { addStep, removeLesson, stepAction, updateLesson } from "../../../actions";

const small = "min-h-tap-ui rounded-md border border-ui-border-input bg-ui-bg px-s3 text-ui-small hover:bg-ui-surface";

export default async function LessonPage({ params }: { params: Promise<{ id: string; lessonId: string }> }) {
  const { id, lessonId } = await params;
  const { admin, db } = await requireAdmin(["content.read"]);
  const c = await getCourse(db, id);
  const all = c.modules.flatMap((m) => m.lessons);
  const l = all.find((x) => x.id === lessonId);
  if (!l) notFound();
  const editable = canAny(admin.permissions, ["content.write"]) && c.status !== "in_review" && (!["approved", "published"].includes(c.status) || canAny(admin.permissions, ["content.publish"]));
  const imgs = await listAssets(db, { kind: "image", status: "ready", pageSize: 200 });
  // the 100 most recently changed activities (search the activity list for older ones)
  const choices = editable ? (await listActivities(db, { pageSize: 100 })).rows : [];
  return (
    <>
      <PageHeader title={l.title} back={{ href: `/content/courses/${c.id}`, label: c.title }} subtitle={<>Lesson in <StatusBadge status={c.status} /> course</>} />
      <div className="flex flex-col gap-s6">
        <Card title="Lesson">
          <LessonForm action={updateLesson.bind(null, c.id, l.id)} l={l} canWrite={editable} images={imgs.rows.map((x) => ({ value: x.id, label: x.path }))}
            siblings={all.filter((x) => x.id !== l.id).map((x) => ({ value: x.id, label: x.title }))} />
        </Card>
        <Card title="Activities in this lesson">
          <p className="mb-s4 text-ui-small text-ui-text-muted">Children play them in this order. A course can only be published when every activity in it is published.</p>
          <Table head={["#", "Activity", "Step", "Required", ""]}>
            {l.steps.map((s, i) => (
              <tr key={s.id}>
                <td>{i + 1}</td>
                <td><Link className="text-ui-primary hover:underline" href={`/content/activities/${s.activityId}`}>{s.activityTitle}</Link> <StatusBadge status={s.activityStatus} /></td>
                <td>{s.type}</td>
                <td>{s.required ? "Yes" : "Optional"}</td>
                <td className="flex flex-wrap gap-s2">
                  {editable && <>
                    <form action={stepAction.bind(null, c.id, l.id, s.id, "up")}><button className={small} aria-label={`Move step ${i + 1} up`}>↑</button></form>
                    <form action={stepAction.bind(null, c.id, l.id, s.id, "down")}><button className={small} aria-label={`Move step ${i + 1} down`}>↓</button></form>
                    <form action={stepAction.bind(null, c.id, l.id, s.id, s.required ? "optional" : "required")}><button className={small}>{s.required ? "Make optional" : "Make required"}</button></form>
                    <form action={stepAction.bind(null, c.id, l.id, s.id, "remove")}><button className={small}>Remove</button></form>
                  </>}
                </td>
              </tr>
            ))}
          </Table>
          {editable && (
            <div className="mt-s5">
              <ActionForm action={addStep.bind(null, c.id, l.id)}>
                <div className="grid gap-s4 md:grid-cols-3">
                  <SelectField name="activityId" label="Activity" options={choices.map((a) => ({ value: a.id, label: `${a.title || a.slug} (${a.type}, ${a.status})` }))} />
                  <SelectField name="type" label="Step type" initial="practice" options={STEP_TYPES.map((t) => ({ value: t, label: t }))} />
                  <CheckField name="required" label="Required to finish the lesson" initial />
                </div>
                <div><Submit>Add activity</Submit></div>
              </ActionForm>
            </div>
          )}
        </Card>
        {editable && (
          <Card title="Delete">
            <ConfirmAction action={removeLesson.bind(null, c.id, l.id)} label="Delete this lesson" danger title="Delete this lesson?" message="Its steps go with it; the activities stay." confirm="Delete" />
          </Card>
        )}
      </div>
    </>
  );
}
