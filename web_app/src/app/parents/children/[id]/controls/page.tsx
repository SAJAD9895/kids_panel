import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ActionForm, CheckField, Submit } from "@/components/form";
import { Card, Notice, PageHeader } from "@/components/ui";
import { localDate, t } from "@/lib/format";
import { listChildren, requireGrownUp } from "@/lib/session";
import { saveControls } from "../../../actions";

export const metadata: Metadata = { title: "Screen time and controls" };
const LIMITS = [["", "No daily limit"], ["15", "15 minutes"], ["30", "30 minutes"], ["45", "45 minutes"], ["60", "1 hour"], ["90", "1½ hours"], ["120", "2 hours"], ["180", "3 hours"]];

export default async function Controls({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { db, family } = await requireGrownUp(`/parents/children/${id}/controls`);
  const [kids, rules, cats, usage] = await Promise.all([
    listChildren(db),
    db.from("screen_time_rules").select("learn_enabled, watch_enabled, listen_enabled, together_enabled, daily_limit_minutes, limited_sections, blocked_category_ids").eq("child_id", id).maybeSingle(),
    db.from("categories").select("id, name").eq("status", "published").order("sort"),
    db.from("screen_time_usage").select("section, seconds").eq("child_id", id).eq("local_date", localDate(family.timezone)),
  ]);
  const k = kids.find((c) => c.id === id);
  if (!k) notFound();
  const r = rules.data ?? { learn_enabled: true, watch_enabled: true, listen_enabled: true, together_enabled: true, daily_limit_minutes: null, limited_sections: ["watch", "listen"], blocked_category_ids: [] };
  const blocked = new Set<string>(r.blocked_category_ids ?? []);
  const limited = new Set<string>(r.limited_sections ?? []);
  return (
    <>
      <PageHeader title={`${k.nickname}: screen time and controls`} back={{ href: `/parents/children/${id}`, label: k.nickname }} subtitle="These apply on every device, the web and the app alike: the server checks them each time something opens." />
      <ActionForm action={saveControls.bind(null, id)}>
        <div className="grid gap-s6 lg:grid-cols-2">
          <Card title="Sections">
            <div className="flex flex-col gap-s3">
              <CheckField name="learn" label="Learn (courses and lessons)" initial={r.learn_enabled} />
              <CheckField name="watch" label="Videos" initial={r.watch_enabled} />
              <CheckField name="listen" label="Songs and stories" initial={r.listen_enabled} />
              <CheckField name="together" label="Play together" initial={r.together_enabled} />
              <p className="text-ui-small text-ui-text-muted">Games are always on and never limited.</p>
            </div>
          </Card>
          <Card title="Daily limit">
            <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">Time per day</span>
              <select name="limit" defaultValue={r.daily_limit_minutes ? String(r.daily_limit_minutes) : ""} className="min-h-tap-ui rounded-md border border-ui-border-input bg-ui-bg px-s3">
                {LIMITS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
            </label>
            <fieldset className="mt-s4 flex flex-col gap-s2"><legend className="text-ui-body-strong">The limit counts</legend>
              {[["watch", "Videos"], ["listen", "Songs and stories"]].map(([v, l]) => (
                <label key={v} className="flex items-center gap-s3"><input type="checkbox" name="limited" value={v} defaultChecked={limited.has(v)} className="size-icon-md accent-ui-primary" />{l}</label>
              ))}
            </fieldset>
            <p className="mt-s4 text-ui-small text-ui-text-muted">Used today: {Math.round((usage.data ?? []).filter((u) => limited.has(u.section as string)).reduce((n, u) => n + Number(u.seconds), 0) / 60)} minutes of what the limit counts.</p>
          </Card>
          <Card title="Categories" className="lg:col-span-2">
            <p className="mb-s3 text-ui-small text-ui-text-muted">Switch off a category to hide its videos, songs and stories.</p>
            <div className="grid gap-s2 sm:grid-cols-2 lg:grid-cols-3">
              {(cats.data ?? []).map((c) => (
                <label key={c.id as string} className="flex items-center gap-s3"><input type="hidden" name="allCategories" value={c.id as string} />
                  <input type="checkbox" name="category" value={c.id as string} defaultChecked={!blocked.has(c.id as string)} className="size-icon-md accent-ui-primary" />{t(c.name)}</label>
              ))}
            </div>
          </Card>
        </div>
        <div className="mt-s5"><Submit>Save controls</Submit></div>
      </ActionForm>
      <div className="mt-s6"><Notice>Age-appropriate content is automatic: {k.nickname} only sees activities for their age.</Notice></div>
    </>
  );
}
