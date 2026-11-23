import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { privacyRequests } from "@/lib/data/people";
import { canAny } from "@/lib/permissions";
import { ConfirmAction } from "@/components/form";
import { Card, dateTime, EmptyState, PageHeader, StatusBadge, Table } from "@/components/ui";
import { runExport } from "./actions";

export default async function Privacy({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const sp = await searchParams;
  const { admin, db } = await requireAdmin(["privacy.act", "support.read"]);
  const [exports, deletions] = await Promise.all([privacyRequests(db, "export", sp.status), privacyRequests(db, "deletion", sp.status)]);
  const privacy = canAny(admin.permissions, ["privacy.act"]);
  return (
    <>
      <PageHeader title="Data requests" subtitle="Exports and deletions families asked for. Parents make and cancel them in the app; due deletions run on the scheduled job." />
      <div className="flex flex-col gap-s6">
        <Card title="Exports">
          {exports.length === 0 ? <EmptyState title="No export requests" /> : (
            <Table head={["Family", "Scope", "Status", "Asked", "Kept until", ""]}>
              {exports.map((e) => (
                <tr key={e.id}>
                  <td><Link className="text-ui-primary hover:underline" href={`/families/${e.accountId}`}>{e.ownerEmail}</Link></td>
                  <td>{e.scope}</td><td><StatusBadge status={e.status} /></td><td className="text-ui-small">{dateTime(e.createdAt)}</td><td className="text-ui-small">{dateTime(e.expiresAt)}</td>
                  <td>{privacy && ["requested", "failed", "processing"].includes(e.status) && (
                    <ConfirmAction action={runExport.bind(null, e.id)} label="Build now" title="Build this export?" message="The file is made from the family's current data and kept 7 days. The parent gets a notice." confirm="Build" />)}</td>
                </tr>
              ))}
            </Table>
          )}
        </Card>
        <Card title="Deletions">
          {deletions.length === 0 ? <EmptyState title="No deletion requests" /> : (
            <Table head={["Family", "Scope", "Status", "Due", "Done"]}>
              {deletions.map((d) => (
                <tr key={d.id}>
                  <td><Link className="text-ui-primary hover:underline" href={`/families/${d.accountId}`}>{d.ownerEmail ?? d.accountId}</Link></td>
                  <td>{d.scope}</td><td><StatusBadge status={d.status} /></td><td className="text-ui-small">{dateTime(d.scheduledFor)}</td><td className="text-ui-small">{dateTime(d.completedAt)}</td>
                </tr>
              ))}
            </Table>
          )}
          <p className="mt-s3 text-ui-small text-ui-text-muted">Support can cancel a scheduled deletion from the family&apos;s page when the parent asks.</p>
        </Card>
      </div>
    </>
  );
}
