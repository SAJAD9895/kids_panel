import type { Metadata } from "next";
import Link from "next/link";
import { BuddyArt, buddyIndex } from "@/components/buddy-art";
import { Card, EmptyState, LinkButton, Notice, PageHeader } from "@/components/ui";
import { ageYears } from "@/lib/format";
import { listChildren, requireGrownUp } from "@/lib/session";

export const metadata: Metadata = { title: "Children" };

export default async function Children({ searchParams }: { searchParams: Promise<{ deleted?: string }> }) {
  const sp = await searchParams;
  const { db } = await requireGrownUp("/parents/children");
  const kids = await listChildren(db);
  return (
    <>
      <PageHeader title="Children" subtitle="Each child has their own profile, progress, goals and controls." actions={<LinkButton href="/parents/children/new" variant="primary">Add a child</LinkButton>} />
      {sp.deleted && <div className="mb-s5"><Notice tone="success">The child&apos;s profile and all their data were deleted.</Notice></div>}
      {kids.length === 0 ? <EmptyState title="No children yet" /> : (
        <ul className="grid gap-s4 md:grid-cols-2">
          {kids.map((k) => (
            <li key={k.id}><Card>
              <div className="flex items-center gap-s4">
                <span className="size-tap-kids shrink-0 rounded-pill bg-kids-me-soft p-s1"><BuddyArt index={buddyIndex(k.avatarKey)} /></span>
                <div className="min-w-0 flex-1"><p className="truncate text-ui-h3">{k.nickname}</p><p className="text-ui-small text-ui-text-muted">{ageYears(k.birthYearMonth)} years</p></div>
                <Link href={`/parents/children/${k.id}`} className="min-h-tap-ui rounded-md px-s3 py-s2 text-ui-primary underline">Edit</Link>
              </div>
              <nav className="mt-s4 flex flex-wrap gap-s2 text-ui-small" aria-label={`${k.nickname}'s pages`}>
                <Link className="rounded-md bg-ui-surface px-s3 py-s2" href={`/parents/children/${k.id}/report`}>Report</Link>
                <Link className="rounded-md bg-ui-surface px-s3 py-s2" href={`/parents/children/${k.id}/rewards`}>Goals and rewards</Link>
                <Link className="rounded-md bg-ui-surface px-s3 py-s2" href={`/parents/children/${k.id}/controls`}>Screen time and controls</Link>
              </nav>
            </Card></li>
          ))}
        </ul>
      )}
    </>
  );
}
