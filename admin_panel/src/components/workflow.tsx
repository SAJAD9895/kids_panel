"use client";
// The publishing workflow: only the moves this admin may make from the current status.
// The server checks the same rules (admin_api.transition), plus validation and four-eyes review.
import { ConfirmAction, type FormResult } from "./form";
import { STATUS_LABEL } from "./ui";

type Action = (prev: FormResult, fd: FormData) => Promise<FormResult>;
type Move = { to: string; label: string; need: "content.write" | "content.publish"; note?: string; danger?: boolean; message: string };
const MOVES: Record<string, Move[]> = {
  draft: [{ to: "in_review", label: "Send for review", need: "content.write", message: "A content manager will review it. You can't edit it while it's in review unless it's sent back." }],
  in_review: [
    { to: "approved", label: "Approve", need: "content.publish", message: "It passes the checks and is ready to publish. Approved content is locked." },
    { to: "draft", label: "Send back", need: "content.write", note: "What needs changing?", message: "It goes back to draft for changes." },
  ],
  approved: [
    { to: "published", label: "Publish", need: "content.publish", message: "Children will see it in the app straight away." },
    { to: "draft", label: "Send back", need: "content.publish", note: "Why is it going back?", message: "It goes back to draft for changes." },
  ],
  published: [{ to: "retired", label: "Archive", need: "content.publish", danger: true, message: "Children stop seeing it. Saved progress stays. It can be reopened as a draft." }],
  retired: [{ to: "draft", label: "Reopen as draft", need: "content.write", message: "It becomes an editable draft (still hidden from children)." }],
};

export function Workflow({ table, id, status, permissions, problems, action }: {
  table: "activities" | "courses"; id: string; status: string; permissions: string[]; problems: string[]; action: Action;
}) {
  const moves = (MOVES[status] ?? []).filter((m) => permissions.includes(m.need) || (m.need === "content.write" && permissions.includes("content.publish")));
  const steps = ["draft", "in_review", "approved", "published"];
  return (
    <div className="flex flex-col gap-s4">
      <ol className="flex flex-wrap gap-s2 text-ui-small" aria-label="Workflow">
        {[...steps, "retired"].map((s) => (
          <li key={s} aria-current={s === status ? "step" : undefined}
            className={`rounded-pill px-s3 py-s1 ${s === status ? "bg-ui-primary text-ui-on-primary" : "bg-ui-surface text-ui-text-muted"}`}>{STATUS_LABEL[s]}</li>
        ))}
      </ol>
      {problems.length > 0 && ["draft", "in_review", "approved"].includes(status) && (
        <div className="rounded-md bg-ui-warning-soft p-s4 text-ui-warning-text">
          <p className="text-ui-body-strong">Before it can be approved or published:</p>
          <ul className="mt-s2 list-disc pl-s6 text-ui-body">{problems.map((p) => <li key={p}>{p}</li>)}</ul>
        </div>
      )}
      {problems.length === 0 && status !== "published" && status !== "retired" && <p className="text-ui-small text-ui-success">All publishing checks pass.</p>}
      <div className="flex flex-wrap gap-s3">
        {moves.length === 0 && <p className="text-ui-small text-ui-text-muted">No workflow action for your role at this stage.</p>}
        {moves.map((m) => (
          <ConfirmAction key={m.to} action={action} label={m.label} title={`${m.label}?`} message={m.message} confirm={m.label}
            danger={m.danger} reason={m.note} hidden={{ table, id, to: m.to }} />
        ))}
      </div>
    </div>
  );
}
