import { requireAdmin } from "@/lib/auth";
import { activity } from "@/lib/data/admin";
import { dateTime, EmptyState, Filters, PageHeader, Table } from "@/components/ui";
import Link from "next/link";

const sel = "rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui";

export default async function Audit({ searchParams }: { searchParams: Promise<{ table?: string; page?: string }> }) {
  const sp = await searchParams;
  const page = Number(sp.page) || 1;
  const { db } = await requireAdmin(["audit.read"]);
  const rows = await activity(db, page, 50, sp.table);
  return (
    <>
      <PageHeader title="Audit log" subtitle="Every change to accounts, billing, admin roles and content, newest first. It can't be edited or deleted." />
      <Filters path="/settings/audit">
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Table</span><input name="table" defaultValue={sp.table} placeholder="e.g. activities" className={sel} /></label>
      </Filters>
      {rows.length === 0 ? <EmptyState title="No entries" /> : (
        <Table head={["When", "Who", "Action", "Table", "Item", "Changes"]}>
          {rows.map((r) => (
            <tr key={r.id}>
              <td className="whitespace-nowrap text-ui-small">{dateTime(r.at)}</td><td className="text-ui-small">{r.actor ?? r.actorType}</td>
              <td>{r.action}</td><td className="font-mono text-ui-small">{r.table}</td><td className="font-mono text-ui-small">{r.entityId?.slice(0, 12)}</td>
              <td className="max-w-ui-form-w"><code className="block max-h-ui-topbar-h overflow-auto break-all font-mono text-ui-caption">{JSON.stringify(r.changes)}</code></td>
            </tr>
          ))}
        </Table>
      )}
      <nav className="mt-s5 flex gap-s4 text-ui-small" aria-label="Pages">
        {page > 1 && <Link className="text-ui-primary" href={`/settings/audit?${new URLSearchParams({ ...(sp.table ? { table: sp.table } : {}), page: String(page - 1) })}`}>← Newer</Link>}
        {rows.length === 50 && <Link className="text-ui-primary" href={`/settings/audit?${new URLSearchParams({ ...(sp.table ? { table: sp.table } : {}), page: String(page + 1) })}`}>Older →</Link>}
      </nav>
    </>
  );
}
