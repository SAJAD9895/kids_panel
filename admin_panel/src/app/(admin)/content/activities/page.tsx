import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { listActivities, listSubjects } from "@/lib/data/content";
import { canAny } from "@/lib/permissions";
import { ACTIVITY_TYPES, STATUSES } from "@/lib/validation";
import { date, EmptyState, Filters, LinkButton, PageHeader, Pagination, STATUS_LABEL, StatusBadge, Table } from "@/components/ui";

type SP = { q?: string; type?: string; status?: string; subject?: string; page?: string };
const sel = "rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui";

export default async function Activities({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams;
  const { admin, db } = await requireAdmin(["content.read"]);
  const [res, subjects] = await Promise.all([
    listActivities(db, { q: sp.q, type: sp.type, status: sp.status, subjectId: sp.subject, page: Number(sp.page) || 1 }),
    listSubjects(db),
  ]);
  return (
    <>
      <PageHeader title="Activities and games" subtitle="Games, quizzes, videos, songs and stories."
        actions={canAny(admin.permissions, ["content.write"]) && <LinkButton href="/content/activities/new" variant="primary">New activity</LinkButton>} />
      <Filters path="/content/activities">
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Search</span>
          <input name="q" defaultValue={sp.q} placeholder="Title, slug or keyword" className={sel} /></label>
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Kind</span>
          <select name="type" defaultValue={sp.type ?? ""} className={sel}><option value="">All</option>{ACTIVITY_TYPES.map((t) => <option key={t}>{t}</option>)}</select></label>
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Status</span>
          <select name="status" defaultValue={sp.status ?? ""} className={sel}><option value="">All</option>{STATUSES.map((s) => <option key={s} value={s}>{STATUS_LABEL[s]}</option>)}</select></label>
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Subject</span>
          <select name="subject" defaultValue={sp.subject ?? ""} className={sel}><option value="">All</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></label>
      </Filters>
      {res.rows.length === 0 ? <EmptyState title="No activities match">Try another search or filter.</EmptyState> : (
        <Table head={["Title", "Kind", "Subject", "Ages", "Status", "Changed"]}>
          {res.rows.map((a) => (
            <tr key={a.id}>
              <td className="max-w-ui-form-w"><Link className="break-words text-ui-primary hover:underline" href={`/content/activities/${a.id}`}>{a.title || a.slug}</Link>
                <div className="font-mono text-ui-caption text-ui-text-muted">{a.slug}</div></td>
              <td>{a.type}</td>
              <td>{a.subject ?? "—"}</td>
              <td className="whitespace-nowrap text-ui-small">{Math.floor(a.ageMin / 12)}–{Math.floor(a.ageMax / 12)} y</td>
              <td><StatusBadge status={a.status} /></td>
              <td className="whitespace-nowrap text-ui-small">{date(a.updatedAt)}</td>
            </tr>
          ))}
        </Table>
      )}
      <Pagination path="/content/activities" page={res.page} pageSize={res.pageSize} total={res.total} params={{ q: sp.q, type: sp.type, status: sp.status, subject: sp.subject }} />
    </>
  );
}
