/* eslint-disable @next/next/no-img-element -- badge art */
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ActionForm, CheckField, Submit, TextField } from "@/components/form";
import { Card, PageHeader, Table } from "@/components/ui";
import { rewardsOf } from "@/lib/data/rewards";
import { day } from "@/lib/format";
import { listChildren, requireGrownUp } from "@/lib/session";
import { saveGoals } from "../../../actions";

export const metadata: Metadata = { title: "Goals and rewards" };
const REASON: Record<string, string> = { activity_completed: "Finished an activity", lesson_completed: "Finished a lesson", course_completed: "Finished a course", daily_goal_met: "Daily goal", weekly_goal_met: "Weekly goal", badge: "Badge", admin_adjustment: "Added by support" };

export default async function GoalsRewards({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { db, family } = await requireGrownUp(`/parents/children/${id}/rewards`);
  const k = (await listChildren(db)).find((c) => c.id === id);
  if (!k) notFound();
  const r = await rewardsOf(id);
  const earned = r.badges.filter((b) => b.earnedAt);
  return (
    <>
      <PageHeader title={`${k.nickname}: goals and rewards`} back={{ href: `/parents/children/${id}`, label: k.nickname }} />
      <div className="grid gap-s6 lg:grid-cols-2">
        <Card title="Learning goals">
          <ActionForm action={saveGoals.bind(null, id)}>
            <CheckField name="enabled" label="Use goals" initial={r.goals.enabled} help="Goals add a bonus star. Switch them off for free play." />
            <TextField name="daily" label="Activities a day" type="number" min={1} max={10} initial={r.goals.dailyActivities} />
            <TextField name="weekly" label="Learning days a week" type="number" min={1} max={7} initial={r.goals.weeklyDays} />
            <Submit>Save goals</Submit>
          </ActionForm>
        </Card>
        <Card title="So far">
          <dl className="grid grid-cols-2 gap-s3">
            {[["Stars", r.balance], ["Streak", `${r.streak.current} days`], ["Best streak", `${r.streak.longest} days`], ["Badges", `${earned.length} of ${r.badges.length}`], ["Today", `${r.day.progress} of ${r.day.target}`], ["This week", `${r.week.progress} of ${r.week.target} days`]].map(([l, v]) => (
              <div key={String(l)} className="rounded-md bg-ui-surface p-s3"><dt className="text-ui-caption text-ui-text-muted">{l}</dt><dd className="text-ui-h3">{v}</dd></div>
            ))}
          </dl>
          <h3 className="mt-s5 text-ui-body-strong">How stars are earned</h3>
          <ul className="mt-s2 list-disc pl-s5 text-ui-small">{r.rules.map((x) => <li key={x.key}>{x.description}</li>)}</ul>
        </Card>
        <Card title="Badges" className="lg:col-span-2">
          <ul className="grid grid-cols-2 gap-s4 sm:grid-cols-4 xl:grid-cols-6">
            {r.badges.map((b) => (
              <li key={b.key} className="flex flex-col items-center gap-s1 text-center">
                {b.art && <img src={b.art} alt="" loading="lazy" className={`size-kids-node object-contain ${b.earnedAt ? "" : "opacity-30 grayscale"}`} />}
                <span className="text-ui-body-strong">{b.title}</span>
                <span className="text-ui-caption text-ui-text-muted">{b.earnedAt ? `Earned ${day(b.earnedAt, family.timezone)}` : b.howToEarn}</span>
              </li>
            ))}
          </ul>
        </Card>
        <Card title="Recent stars" className="lg:col-span-2">
          <Table head={["When", "For", "Stars"]}>
            {r.transactions.slice(0, 20).map((x, i) => <tr key={i}><td>{day(x.at, family.timezone)}</td><td>{x.badgeTitle ? `Badge: ${x.badgeTitle}` : REASON[x.reason] ?? x.reason}</td><td>+{x.amount}</td></tr>)}
          </Table>
        </Card>
      </div>
    </>
  );
}
