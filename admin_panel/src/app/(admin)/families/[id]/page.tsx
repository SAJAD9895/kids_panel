import { randomUUID } from "node:crypto";
import { notFound } from "next/navigation";
import { requireAdmin } from "@/lib/auth";
import { getFamily } from "@/lib/data/people";
import { AdminError } from "@/lib/errors";
import { canAny } from "@/lib/permissions";
import { ActionForm, ConfirmAction, Submit, TextField } from "@/components/form";
import { Card, EmptyState, date, dateTime, Notice, PageHeader, StatusBadge, Table } from "@/components/ui";
import { addStars, cancelDel, restrict } from "../actions";

export default async function Family({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { admin, db } = await requireAdmin(["support.read"]);
  const f = await getFamily(db, id).catch((e) => { if (e instanceof AdminError) notFound(); throw e; });
  const act = canAny(admin.permissions, ["support.act"]);
  const owner = f.parents.find((p) => p.role === "owner")?.email ?? f.parents[0]?.email ?? id;
  return (
    <>
      <PageHeader title={owner} back={{ href: "/families", label: "Families" }} subtitle={<span className="flex flex-wrap items-center gap-s3"><StatusBadge status={f.status} /> since {date(f.createdAt)} · {f.timezone} · {f.country ?? "no country"}</span>} />
      <div className="flex flex-col gap-s6">
        {f.status === "suspended" && <Notice tone="warning">Suspended: the children can&apos;t play or open media. Parents can still sign in, export and delete.</Notice>}
        <Card title="Account">
          <Table head={["Parent", "Role", "Since"]}>{f.parents.map((p) => <tr key={p.email}><td>{p.email}</td><td>{p.role}</td><td>{date(p.since)}</td></tr>)}</Table>
          {act && f.status !== "pending_deletion" && (
            <div className="mt-s5">
              {f.status === "suspended"
                ? <ConfirmAction action={restrict.bind(null, id, "active")} label="Lift the restriction" title="Make the account active again?" message="The children can play again." confirm="Lift" reason="Reason (kept in the audit log)" />
                : <ConfirmAction action={restrict.bind(null, id, "suspended")} label="Suspend the account" danger title="Suspend this account?" message="The children can't record play or open media until it's lifted. Use only for abuse, fraud or a legal reason." confirm="Suspend" reason="Reason (kept in the audit log)" />}
            </div>
          )}
        </Card>
        <Card title="Children">
          <p className="mb-s4 text-ui-small text-ui-text-muted">Activity is shown as counts only. Birth months, session details and answers aren&apos;t shown to support.</p>
          <Table head={["Nickname", "Age", "Status", "Sessions (30 days)", "Finished (30 days)", "Last active", "Stars", ""]}>
            {f.children.map((c) => (
              <tr key={c.childId}>
                <td>{c.nickname}</td><td>{c.ageYears}</td><td><StatusBadge status={c.status} /></td>
                <td>{c.sessions30d}</td><td>{c.completed30d}</td><td className="text-ui-small">{dateTime(c.lastActive)}</td><td>{c.stars}</td>
                <td>{act && (
                  <details><summary className="cursor-pointer text-ui-primary">Add stars</summary>
                    <ActionForm action={addStars.bind(null, id, c.childId)} className="mt-s3">
                      <input type="hidden" name="requestId" value={randomUUID()} />
                      <TextField name="amount" label="Stars (1–20)" type="number" min={1} max={20} />
                      <TextField name="reason" label="Why (10+ characters, audited)" />
                      <Submit>Add stars</Submit>
                      <p className="text-ui-small text-ui-text-muted">For support cases only (e.g. a lost sync). Stars can&apos;t be removed.</p>
                    </ActionForm>
                  </details>)}</td>
              </tr>
            ))}
          </Table>
        </Card>
        <Card title="Subscriptions">
          {f.subscriptions.length === 0 ? <p className="text-ui-body text-ui-text-muted">Basic (no subscription).</p> : (
            <Table head={["Plan", "Store", "Status", "Period ends", "Environment"]}>
              {f.subscriptions.map((s, i) => <tr key={i}><td>{s.plan}</td><td>{s.provider}</td><td>{s.status}</td><td>{date(s.periodEnd)}</td><td>{s.environment}</td></tr>)}
            </Table>
          )}
        </Card>
        <Card title="Data requests">
          {f.exports.length + f.deletions.length === 0 ? <EmptyState title="No export or deletion requests" /> : <Table head={["Kind", "Status", "When", ""]}>
            {f.exports.map((e) => <tr key={e.id}><td>Export ({e.childId ? "one child" : "account"})</td><td><StatusBadge status={e.status} /></td><td>{dateTime(e.createdAt)}</td><td /></tr>)}
            {f.deletions.map((d) => (
              <tr key={d.id}><td>Deletion ({d.scope})</td><td><StatusBadge status={d.status} /></td><td>{dateTime(d.scheduledFor)}</td>
                <td>{act && d.status === "scheduled" && <ConfirmAction action={cancelDel.bind(null, id, d.id)} label="Cancel deletion" title="Cancel this deletion?" message="Only when the parent asked for it (they can also cancel it themselves)." confirm="Cancel deletion" reason="Reason (kept in the audit log)" />}</td></tr>
            ))}
          </Table>}
        </Card>
      </div>
    </>
  );
}
