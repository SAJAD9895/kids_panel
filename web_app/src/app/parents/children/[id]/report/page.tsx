import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { BarChart } from "@/components/charts";
import { Card, EmptyState, Notice, PageHeader, Table } from "@/components/ui";
import { insights, report } from "@/lib/data/parent";
import { dayTime, minutes } from "@/lib/format";
import { listChildren, requireGrownUp } from "@/lib/session";

export const metadata: Metadata = { title: "Progress report" };
const PERIODS = [["day", "Day"], ["week", "Week"], ["month", "Month"]] as const;
const KIND: Record<string, string> = { game: "Games", quiz: "Quizzes", video: "Videos", song: "Songs", story: "Stories", audio_story: "Audio stories", together: "Together", printable: "Printables" };
const BAND: Record<string, string> = { getting_started: "Getting started", practising: "Practising", confident: "Confident" };
const shift = (iso: string, period: string, dir: number) => {
  const d = new Date(`${iso.slice(0, 10)}T12:00:00Z`);
  if (period === "day") d.setUTCDate(d.getUTCDate() + dir);
  else if (period === "week") d.setUTCDate(d.getUTCDate() + 7 * dir);
  else d.setUTCMonth(d.getUTCMonth() + dir);
  return d.toISOString().slice(0, 10);
};
const pct = (v: number | null) => (v === null ? "—" : `${Math.round(v)} %`);

export default async function ReportPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ period?: string; date?: string }> }) {
  const [{ id }, sp] = await Promise.all([params, searchParams]);
  const period = ["day", "week", "month"].includes(sp.period ?? "") ? sp.period! : "week";
  const { db, family } = await requireGrownUp(`/parents/children/${id}/report`);
  const kids = await listChildren(db);
  const k = kids.find((c) => c.id === id);
  if (!k) notFound();
  const r = await report(id, period, sp.date);
  const { strong, practise } = insights(r);
  const ongoing = r.to >= r.today;
  const url = (p: string, d?: string) => `/parents/children/${id}/report?period=${p}${d ? `&date=${d}` : ""}`;
  const empty = r.totals.sessions === 0;
  const dayLabel = (iso: string) => new Intl.DateTimeFormat("en-GB", period === "month" ? { day: "numeric" } : { weekday: "short" }).format(new Date(iso.slice(0, 10)));
  return (
    <>
      <PageHeader title={`${k.nickname}'s progress`} back={{ href: "/parents", label: "Overview" }} subtitle={`${r.from}${r.from !== r.to ? ` to ${r.to}` : ""}${ongoing ? " · this period isn't over yet: numbers can still grow" : ""}`} />
      <div className="mb-s6 flex flex-wrap items-center gap-s3">
        {kids.length > 1 && (
          <nav aria-label="Child" className="flex gap-s1 rounded-md bg-ui-surface p-s1">
            {kids.map((c) => <Link key={c.id} href={`/parents/children/${c.id}/report?period=${period}`} aria-current={c.id === id ? "page" : undefined} className={`min-h-tap-ui rounded-md px-s3 py-s2 ${c.id === id ? "bg-ui-bg font-semibold shadow-card" : ""}`}>{c.nickname}</Link>)}
          </nav>
        )}
        <nav aria-label="Period" className="flex gap-s1 rounded-md bg-ui-surface p-s1">
          {PERIODS.map(([p, l]) => <Link key={p} href={url(p, sp.date)} aria-current={p === period ? "page" : undefined} className={`min-h-tap-ui rounded-md px-s4 py-s2 ${p === period ? "bg-ui-bg font-semibold shadow-card" : ""}`}>{l}</Link>)}
        </nav>
        <div className="flex gap-s2">
          <Link href={url(period, shift(r.from, period, -1))} className="min-h-tap-ui rounded-md border border-ui-border-input px-s4 py-s2">← Earlier</Link>
          {!ongoing && <Link href={url(period, shift(r.from, period, 1))} className="min-h-tap-ui rounded-md border border-ui-border-input px-s4 py-s2">Later →</Link>}
        </div>
      </div>
      <dl className="mb-s6 grid grid-cols-2 gap-s3 md:grid-cols-3 xl:grid-cols-6">
        {[["Learning time", minutes(r.totals.seconds), r.previous.seconds ? `before: ${minutes(r.previous.seconds)}` : ""], ["Activities finished", r.totals.completed, `before: ${r.previous.completed}`], ["Different activities", r.totals.activities, ""], ["Learning days", r.totals.learningDays, ""], ["Stars earned", r.totals.stars, ""], ["Lessons finished", r.lessons.completedInPeriod, `${r.lessons.completedTotal} in all`]].map(([l, v, n]) => (
          <div key={String(l)} className="rounded-md bg-ui-surface p-s4"><dt className="text-ui-caption text-ui-text-muted">{l}</dt><dd className="text-ui-h2 tabular-nums">{v}</dd>{n && <dd className="text-ui-caption text-ui-text-muted">{n}</dd>}</div>
        ))}
      </dl>
      {empty ? <EmptyState title={`No activity in this ${period}`}>Choose another period, or come back after some play.</EmptyState> : (
        <div className="flex flex-col gap-s6">
          <Card title="What stands out">
            {strong.length || practise.length ? (
              <div className="grid gap-s4 md:grid-cols-2">
                <div><h3 className="text-ui-body-strong">Doing well</h3><p className="text-ui-body">{strong.join(", ") || "—"}</p></div>
                <div><h3 className="text-ui-body-strong">Worth practising</h3><p className="text-ui-body">{practise.join(", ") || "—"}</p></div>
              </div>
            ) : <p className="text-ui-body text-ui-text-muted">Not enough scored activity yet to say.</p>}
            <p className="mt-s3 text-ui-caption text-ui-text-muted">A subject needs at least 3 scored activities (80 % and up is &quot;doing well&quot;, under 60 % &quot;worth practising&quot;); a skill needs at least 3 updates.</p>
          </Card>
          <div className="grid gap-s6 xl:grid-cols-2">
            <Card><BarChart title="Learning time" summary={`${minutes(r.totals.seconds)} in total, over ${r.totals.learningDays} learning days.`} bars={r.daily.map((d) => ({ label: dayLabel(d.date), value: Math.round(d.seconds / 60), note: `${d.completed} finished`, highlight: d.date.slice(0, 10) === r.today }))} format={(v) => `${v} min`} /></Card>
            <Card><BarChart title="Finished, by kind" summary={r.byType.map((t) => `${KIND[t.type] ?? t.type}: ${t.completed} of ${t.started}`).join("; ") || "Nothing yet."} bars={r.byType.map((t) => ({ label: KIND[t.type] ?? t.type, value: t.completed, note: `${t.started} started` }))} /></Card>
            <Card><BarChart title="Subjects" summary={r.bySubject.map((s) => `${s.name}: ${s.completed}`).join("; ")} bars={r.bySubject.map((s) => ({ label: s.name, value: s.completed, note: s.scored ? `average ${pct(s.avgScore)} over ${s.scored} scored` : "not scored" }))} /></Card>
            <Card><BarChart title="Weekly consistency" summary="Learning days in each of the last 8 weeks." bars={r.consistency.map((c) => ({ label: c.weekStart.slice(5), value: c.learningDays, note: "of 7 days" }))} max={7} /></Card>
          </div>
          {r.skills.length > 0 && (
            <Card><BarChart title="Skills" summary={r.skills.map((s) => `${s.name}: ${BAND[s.band] ?? s.band}`).join("; ")} bars={r.skills.map((s) => ({ label: s.name, value: Math.round(s.mastery * 100), note: `${BAND[s.band] ?? s.band}${s.practisedInPeriod ? ", practised in this period" : ""}` }))} max={100} format={(v) => `${v} %`} /></Card>
          )}
          {r.goals.enabled && <Card title="Goals"><p className="text-ui-body">Daily goal ({r.goals.dailyTarget} activities) reached on {r.goals.daysReached} of {r.goals.daysElapsed} days. Weekly goal ({r.goals.weeklyTarget} days): {r.goals.weeks.filter((w) => w.reached).length} of {r.goals.weeks.length} weeks.</p></Card>}
          {r.games.length > 0 && (
            <Card title="Games"><Table head={["Game", "Plays", "Finished", "Average", "Best", "Right answers", "Levels"]}>
              {r.games.map((g) => <tr key={g.slug}><td>{g.title}</td><td>{g.plays}</td><td>{g.completed}</td><td>{pct(g.avgScore)}</td><td>{pct(g.bestScore)}</td><td>{g.accuracy === null ? "—" : `${Math.round(g.accuracy * 100)} %`}</td><td>{g.levels.join(", ") || "—"}</td></tr>)}
            </Table></Card>
          )}
          {r.quizzes.length > 0 && (
            <Card title="Quizzes"><Table head={["Quiz", "Attempts", "Last", "Best", "Average", "Right first time"]}>
              {r.quizzes.map((q) => <tr key={q.slug}><td>{q.title}</td><td>{q.attempts}</td><td>{pct(q.lastScore)}</td><td>{pct(q.bestScore)}</td><td>{pct(q.avgScore)}</td><td>{q.firstTryCorrect === null ? "—" : `${Math.round(q.firstTryCorrect * 100)} %`}</td></tr>)}
            </Table></Card>
          )}
          <Card title="Recent activity"><Table head={["When", "Activity", "Kind", "Result", "Time"]}>
            {r.recent.map((x, i) => <tr key={i}><td className="whitespace-nowrap">{dayTime(x.startedAt, family.timezone)}</td><td>{x.title}</td><td>{KIND[x.type] ?? x.type}</td><td>{x.status === "completed" ? (x.score != null ? `finished, ${Math.round(x.score)} %` : "finished") : "stopped early"}</td><td>{x.seconds ? minutes(x.seconds) : "—"}</td></tr>)}
          </Table></Card>
          <Notice>Every number is counted from what {k.nickname} actually did, on this app and the mobile app alike. Nothing is estimated, and children are never compared with each other.</Notice>
        </div>
      )}
    </>
  );
}
