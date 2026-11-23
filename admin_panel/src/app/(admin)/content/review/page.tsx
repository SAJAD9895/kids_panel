import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { reviewQueue } from "@/lib/data/content";
import { date, EmptyState, PageHeader, StatusBadge, Table } from "@/components/ui";

export default async function Review() {
  const { db } = await requireAdmin(["content.read"]);
  const q = await reviewQueue(db);
  return (
    <>
      <PageHeader title="Review queue" subtitle="Content sent for review, and approved content waiting to be published. Oldest first." />
      {q.length === 0 ? <EmptyState title="Nothing to review">When an editor sends something for review it appears here.</EmptyState> : (
        <Table head={["Item", "Kind", "Status", "Waiting since"]}>
          {q.map((i) => (
            <tr key={i.id}>
              <td><Link className="text-ui-primary hover:underline" href={i.table === "courses" ? `/content/courses/${i.id}` : `/content/activities/${i.id}`}>{i.title || "(untitled)"}</Link></td>
              <td>{i.kind}</td>
              <td><StatusBadge status={i.status} /></td>
              <td className="text-ui-small">{date(i.updatedAt)}</td>
            </tr>
          ))}
        </Table>
      )}
    </>
  );
}
