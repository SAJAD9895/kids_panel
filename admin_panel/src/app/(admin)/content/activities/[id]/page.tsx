import { notFound } from "next/navigation";
import { requireAdmin } from "@/lib/auth";
import { getActivity, history, listCategories, listSubjects, validateContent } from "@/lib/data/content";
import { getGameConfig, listQuestions } from "@/lib/data/games";
import { listAssets, listAttachments, ROLES } from "@/lib/data/media";
import { listRewardRules } from "@/lib/data/rewards";
import { canAny } from "@/lib/permissions";
import { ActivityForm } from "@/components/activity-form";
import { GameBuilder } from "@/components/game-builder";
import { QuizEditor } from "@/components/quiz-editor";
import { Workflow } from "@/components/workflow";
import { ActionForm, ConfirmAction, SelectField, Submit, TextField } from "@/components/form";
import { Card, dateTime, Notice, PageHeader, StatusBadge, Table } from "@/components/ui";
import { AdminError } from "@/lib/errors";
import { attachMedia, detachMedia, moveStatus, removeActivity, saveConfig, saveQuizQuestion, updateActivity, removeQuestion } from "../actions";

const LOCKED = ["in_review", "approved", "published"];

export default async function ActivityPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ created?: string }> }) {
  const { id } = await params;
  const { created } = await searchParams;
  const { admin, db } = await requireAdmin(["content.read"]);
  const a = await getActivity(db, id).catch((e) => { if (e instanceof AdminError) notFound(); throw e; });
  const [subjects, categories, images, problems, hist, rules] = await Promise.all([
    listSubjects(db), listCategories(db), listAssets(db, { kind: "image", status: "ready", pageSize: 200 }),
    validateContent(db, "activities", id), history(db, "activities", id).catch(() => []), listRewardRules(db),
  ]);
  const p = admin.permissions;
  const editable = canAny(p, ["content.write"]) && (!LOCKED.includes(a.status) || canAny(p, ["content.publish"])) && a.status !== "in_review";
  const writeNote = !editable && canAny(p, ["content.write"])
    ? a.status === "in_review" ? "In review: send it back to draft to change it." : "Live or approved content can only be changed by a content manager." : null;
  const stars = rules.find((r) => r.key === "activity_completed" && r.active)?.stars ?? 0;

  return (
    <>
      <PageHeader title={a.title || a.slug} back={{ href: "/content/activities", label: "Activities" }}
        subtitle={<span className="flex flex-wrap items-center gap-s3"><StatusBadge status={a.status} /> {a.type} · version {a.contentVersion}{a.publishedAt ? ` · first published ${dateTime(a.publishedAt)}` : ""}</span>} />
      <div className="flex flex-col gap-s6">
        {created && <Notice tone="success">Created as a draft. Add its content below, then send it for review.</Notice>}
        {writeNote && <Notice tone="info">{writeNote}</Notice>}
        <Card title="Publishing">
          <Workflow table="activities" id={a.id} status={a.status} permissions={p} problems={problems} action={moveStatus} />
        </Card>
        <Card title="Details">
          <ActivityForm action={updateActivity.bind(null, a.id)} a={a} canWrite={editable}
            subjects={subjects.map((s) => ({ value: s.id, label: s.name }))} categories={categories.map((c) => ({ value: c.id, label: c.name }))}
            images={images.rows.map((i) => ({ value: i.id, label: i.path }))} />
        </Card>
        {a.type === "game" && (
          <Card title="Game builder">
            <GameBuilder initial={await getGameConfig(db, a.id)} save={saveConfig.bind(null, a.id)} canWrite={editable} starsPerGame={stars} />
          </Card>
        )}
        {a.type === "quiz" && <QuizSection id={a.id} editable={editable} />}
        {["video", "song", "story", "audiobook"].includes(a.type) && <MediaSection id={a.id} type={a.type} editable={editable} />}
        <Card title="History">
          {hist.length === 0 ? <p className="text-ui-small text-ui-text-muted">No recorded changes (or your role can&apos;t see the log).</p> : (
            <Table head={["When", "Who", "What"]}>
              {hist.slice(0, 30).map((h) => (
                <tr key={h.id}><td className="whitespace-nowrap text-ui-small">{dateTime(h.at)}</td><td className="text-ui-small">{h.actor ?? h.actorType}</td>
                  <td className="text-ui-small">{h.action}{typeof h.changes?.note === "string" ? ` — “${h.changes.note}”` : ""}</td></tr>
              ))}
            </Table>
          )}
        </Card>
        {editable && a.status === "draft" && (
          <Card title="Delete">
            <ConfirmAction action={removeActivity.bind(null, a.id)} label="Delete this draft" danger title="Delete this draft?"
              message="It's removed for good. Drafts used in a course can't be deleted until removed from the course." confirm="Delete" />
          </Card>
        )}
      </div>
    </>
  );

  async function QuizSection({ id, editable }: { id: string; editable: boolean }) {
    const qs = await listQuestions(db, id);
    return (
      <Card title="Quiz questions">
        <QuizEditor questions={qs} save={saveQuizQuestion.bind(null, id)} canWrite={editable} />
        {editable && qs.length > 0 && (
          <div className="mt-s4 flex flex-wrap gap-s3">
            {qs.map((q, i) => <ConfirmAction key={q.id} action={removeQuestion.bind(null, id, q.id)} label={`Remove question ${i + 1}`} title="Remove this question?" message={q.prompt} confirm="Remove" danger />)}
          </div>
        )}
      </Card>
    );
  }

  async function MediaSection({ id, type, editable }: { id: string; type: string; editable: boolean }) {
    const [att, assets] = await Promise.all([listAttachments(db, id), listAssets(db, { status: "ready", pageSize: 200 })]);
    const needs = type === "video" ? "a video (video_main) and captions (subtitle)" : type === "story" ? "page pictures (page_image), in order, each with its words" : "an audio file (audio_main)";
    return (
      <Card title="Files">
        <p className="mb-s4 text-ui-small text-ui-text-muted">This {type} needs {needs}. Upload files in the media library first.</p>
        <Table head={["For", "Language", "Order", "File", "Words", ""]}>
          {att.map((m) => (
            <tr key={`${m.role}-${m.locale}-${m.position}`}>
              <td>{m.role}</td><td>{m.locale}</td><td>{m.position}</td>
              <td className="break-all font-mono text-ui-small">{m.asset.path} <StatusBadge status={m.asset.status} /></td>
              <td className="text-ui-small">{m.text ?? ""}</td>
              <td>{editable && <ConfirmAction action={detachMedia.bind(null, id, m.role, m.locale, m.position)} label="Remove" title="Remove this file?" message={m.asset.path} confirm="Remove" />}</td>
            </tr>
          ))}
        </Table>
        {editable && (
          <div className="mt-s5">
            <ActionForm action={attachMedia.bind(null, id)} resetOnOk>
              <div className="grid gap-s4 md:grid-cols-3">
                <SelectField name="role" label="For" options={ROLES.map((r) => ({ value: r, label: r }))} />
                <SelectField name="assetId" label="File" options={assets.rows.map((x) => ({ value: x.id, label: `${x.kind} · ${x.path}` }))} />
                <TextField name="locale" label="Language" initial="und" help="und = any language; en, es… for captions and narration" />
                <TextField name="position" label="Order (story pages)" type="number" initial={0} min={0} max={99} />
                <div className="md:col-span-2"><TextField name="text" label="Words on this page (stories)" maxLength={400} /></div>
              </div>
              <div><Submit>Attach</Submit></div>
            </ActionForm>
          </div>
        )}
      </Card>
    );
  }
}
