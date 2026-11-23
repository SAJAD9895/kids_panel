import type { Metadata } from "next";
import Link from "next/link";
import { BuddyArt, buddyIndex } from "@/components/buddy-art";
import { Card, EmptyState, LinkButton, Notice, PageHeader } from "@/components/ui";
import { overview } from "@/lib/data/parent";
import { ageYears, dayTime, minutes } from "@/lib/format";
import { listChildren, requireGrownUp } from "@/lib/session";

export const metadata: Metadata = { title: "Overview" };
const KIND: Record<string, string> = { game: "Game", quiz: "Quiz", video: "Video", song: "Song", story: "Story", audio_story: "Audio story" };

export default async function ParentHome() {
  const { db, family } = await requireGrownUp("/parents");
  const [kids, ov] = await Promise.all([listChildren(db), overview()]);
  const byId = new Map(ov.children.map((c) => [c.childId, c]));
  return (
    <>
      <PageHeader title="Your family" subtitle={`Today is ${new Intl.DateTimeFormat("en-GB", { weekday: "long", day: "numeric", month: "long", timeZone: family.timezone }).format(new Date())}.`}
        actions={<LinkButton href="/parents/children/new">Add a child</LinkButton>} />
      {ov.unread > 0 && <div className="mb-s5"><Notice><Link href="/parents/notifications" className="underline">You have {ov.unread} new {ov.unread === 1 ? "notice" : "notices"}.</Link></Notice></div>}
      {kids.length === 0 ? <EmptyState title="No children yet" action={<LinkButton href="/parents/children/new" variant="primary">Add a child</LinkButton>} /> : (
        <div className="grid gap-s5 xl:grid-cols-2">
          {kids.map((k) => {
            const o = byId.get(k.id);
            const r = o?.rewards;
            return (
              <Card key={k.id}>
                <div className="flex items-center gap-s4">
                  <span className="size-tap-kids shrink-0 rounded-pill bg-kids-me-soft p-s1"><BuddyArt index={buddyIndex(k.avatarKey)} /></span>
                  <div className="min-w-0"><h2 className="truncate text-ui-h2">{k.nickname}</h2><p className="text-ui-small text-ui-text-muted">{ageYears(k.birthYearMonth)} years</p></div>
                </div>
                <dl className="mt-s5 grid grid-cols-2 gap-s3 sm:grid-cols-4">
                  {[["Today", minutes(o?.secondsToday ?? 0)], ["This week", minutes(o?.secondsWeek ?? 0)], ["Stars", String(r?.balance ?? 0)], ["Streak", `${r?.streak.current ?? 0} days`]].map(([l, v]) => (
                    <div key={l} className="rounded-md bg-ui-surface p-s3"><dt className="text-ui-caption text-ui-text-muted">{l}</dt><dd className="text-ui-h3 tabular-nums">{v}</dd></div>
                  ))}
                </dl>
                {r?.goals.enabled && <p className="mt-s4 text-ui-small">Daily goal: {r.day.progress} of {r.day.target}{r.day.completedAt ? " (reached)" : ""} · Weekly: {r.week.progress} of {r.week.target} days</p>}
                <h3 className="mt-s5 text-ui-body-strong">Recently</h3>
                {o?.recent.length ? (
                  <ul className="mt-s2 flex flex-col divide-y divide-ui-border text-ui-small">
                    {o.recent.slice(0, 5).map((x, i) => <li key={i} className="flex justify-between gap-s3 py-s2"><span className="min-w-0 truncate">{KIND[x.type] ?? x.type}: {x.title}{x.status !== "completed" ? " (stopped early)" : ""}</span><span className="shrink-0 text-ui-text-muted">{dayTime(x.startedAt, family.timezone)}</span></li>)}
                  </ul>
                ) : <p className="mt-s2 text-ui-small text-ui-text-muted">Nothing played yet.</p>}
                <div className="mt-s5 flex flex-wrap gap-s2">
                  <LinkButton href={`/parents/children/${k.id}/report`} variant="primary">Progress report</LinkButton>
                  <LinkButton href={`/parents/children/${k.id}/rewards`}>Goals and rewards</LinkButton>
                  <LinkButton href={`/parents/children/${k.id}/controls`}>Screen time</LinkButton>
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </>
  );
}
