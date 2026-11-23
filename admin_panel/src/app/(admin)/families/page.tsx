import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { listFamilies } from "@/lib/data/people";
import { date, EmptyState, Filters, PageHeader, Pagination, StatusBadge, Table } from "@/components/ui";

const sel = "rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui";

export default async function Families({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  const sp = await searchParams;
  const { db } = await requireAdmin(["support.read"]);
  const r = await listFamilies(db, { q: sp.q, status: sp.status, page: Number(sp.page) || 1 });
  return (
    <>
      <PageHeader title="Families" subtitle="Search by the parent's email or the account id. Children appear by nickname and age only." />
      <Filters path="/families">
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Parent email or account id</span><input name="q" defaultValue={sp.q} className={sel} /></label>
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Status</span>
          <select name="status" defaultValue={sp.status ?? ""} className={sel}><option value="">All</option><option value="active">Active</option><option value="suspended">Suspended</option><option value="pending_deletion">Being deleted</option></select></label>
      </Filters>
      {r.rows.length === 0 ? <EmptyState title="No families match" /> : (
        <Table head={["Parent", "Children", "Plan", "Country", "Status", "Since"]}>
          {r.rows.map((f) => (
            <tr key={f.accountId}>
              <td><Link className="text-ui-primary hover:underline" href={`/families/${f.accountId}`}>{f.ownerEmail}</Link></td>
              <td>{f.children}</td><td>{f.plus ? "Plus" : "Basic"}</td><td>{f.country ?? "—"}</td>
              <td><StatusBadge status={f.status} /></td><td className="text-ui-small">{date(f.createdAt)}</td>
            </tr>
          ))}
        </Table>
      )}
      <Pagination path="/families" page={r.page} pageSize={r.pageSize} total={r.total} params={{ q: sp.q, status: sp.status }} />
    </>
  );
}
