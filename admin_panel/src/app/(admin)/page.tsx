import { requireAdmin } from "@/lib/auth";
import { activity, dashboard } from "@/lib/data/admin";
import { canAny } from "@/lib/permissions";
import { Card, dateTime, EmptyState, Notice, PageHeader, Stat, Table } from "@/components/ui";

export default async function Dashboard() {
  const { admin, db } = await requireAdmin(["content.read", "support.read", "billing.read", "admin.manage"]);
  const d = await dashboard(db);
  const canFeed = canAny(admin.permissions, ["content.read", "audit.read"]);
  const feed = canFeed ? await activity(db, 1, 12) : [];
  return (
    <>
      <PageHeader title="Dashboard" subtitle="Live numbers from the database." />
      {d.mediaFailed > 0 && <div className="mb-s5"><Notice tone="warning">{d.mediaFailed} media file(s) failed processing. See the media library.</Notice></div>}
      <div className="grid grid-cols-2 gap-s4 md:grid-cols-3 xl:grid-cols-5">
        <Stat label="Parents" value={d.parents} href={canAny(admin.permissions, ["support.read"]) ? "/families" : undefined} />
        <Stat label="Children" value={d.children} />
        <Stat label="Active subscriptions" value={d.activeSubscriptions} href={canAny(admin.permissions, ["billing.read"]) ? "/billing" : undefined} />
        <Stat label="Courses" value={d.courses} href="/content/courses" />
        <Stat label="Lessons" value={d.lessons} href="/content/courses" />
        <Stat label="Games" value={d.games} href="/content/activities?type=game" />
        <Stat label="Published (activities + courses)" value={d.published} />
        <Stat label="Waiting for review" value={d.inReview} href="/content/review" />
        <Stat label="Approved, not yet published" value={d.approved} href="/content/review" />
        <Stat label="Drafts" value={d.drafts} href="/content/activities?status=draft" />
      </div>
      <div className="mt-s8">
        <Card title="Recent admin activity">
          {!canFeed ? <p className="text-ui-body text-ui-text-muted">Your role doesn&apos;t include the activity log.</p>
            : feed.length === 0 ? <EmptyState title="Nothing yet" />
            : (
              <Table head={["When", "Who", "What", "Item"]}>
                {feed.map((r) => (
                  <tr key={r.id}>
                    <td className="whitespace-nowrap text-ui-small">{dateTime(r.at)}</td>
                    <td className="text-ui-small">{r.actor ?? r.actorType}</td>
                    <td>{r.action}</td>
                    <td className="text-ui-small">{r.table} <span className="font-mono text-ui-text-muted">{r.entityId?.slice(0, 8)}</span></td>
                  </tr>
                ))}
              </Table>
            )}
        </Card>
      </div>
    </>
  );
}
