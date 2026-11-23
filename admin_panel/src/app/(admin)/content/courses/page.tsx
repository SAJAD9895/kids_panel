import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { listCourses } from "@/lib/data/content";
import { canAny } from "@/lib/permissions";
import { STATUSES, STAGE_AGES } from "@/lib/validation";
import { date, EmptyState, Filters, LinkButton, PageHeader, Pagination, STATUS_LABEL, StatusBadge, Table } from "@/components/ui";

const sel = "rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui";

export default async function Courses({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  const sp = await searchParams;
  const { admin, db } = await requireAdmin(["content.read"]);
  const res = await listCourses(db, { q: sp.q, status: sp.status, page: Number(sp.page) || 1 });
  return (
    <>
      <PageHeader title="Courses and lessons" subtitle="Course → modules → lessons (islands) → activities."
        actions={canAny(admin.permissions, ["content.write"]) && <LinkButton href="/content/courses/new" variant="primary">New course</LinkButton>} />
      <Filters path="/content/courses">
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Search</span><input name="q" defaultValue={sp.q} className={sel} /></label>
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Status</span>
          <select name="status" defaultValue={sp.status ?? ""} className={sel}><option value="">All</option>{STATUSES.map((s) => <option key={s} value={s}>{STATUS_LABEL[s]}</option>)}</select></label>
      </Filters>
      {res.rows.length === 0 ? <EmptyState title="No courses match" /> : (
        <Table head={["Order", "Course", "Ages", "Lessons", "Status", "Changed"]}>
          {res.rows.map((c) => (
            <tr key={c.id}>
              <td>{c.sort}</td>
              <td><Link className="text-ui-primary hover:underline" href={`/content/courses/${c.id}`}>{c.title || c.slug}</Link></td>
              <td className="text-ui-small">{STAGE_AGES[c.stage as keyof typeof STAGE_AGES] ?? c.stage}</td>
              <td>{c.lessons}</td>
              <td><StatusBadge status={c.status} /></td>
              <td className="text-ui-small">{date(c.updatedAt)}</td>
            </tr>
          ))}
        </Table>
      )}
      <Pagination path="/content/courses" page={res.page} pageSize={res.pageSize} total={res.total} params={{ q: sp.q, status: sp.status }} />
    </>
  );
}
