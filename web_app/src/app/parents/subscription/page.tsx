import type { Metadata } from "next";
import { Card, Notice, PageHeader } from "@/components/ui";
import { day } from "@/lib/format";
import { SUB_STATUS } from "@/lib/notices";
import { requireGrownUp } from "@/lib/session";

export const metadata: Metadata = { title: "Subscription" };
const STORE: Record<string, string> = { apple: "App Store", google: "Google Play", stripe: "Web (card)", promo: "Code" };

/** What the billing tables say, with no pretend purchase buttons: payments aren't connected yet
 * (docs/parent-dashboard/subscriptions.md). */
export default async function Subscription() {
  const { db, family } = await requireGrownUp("/parents/subscription");
  const [subs, ent, plans] = await Promise.all([
    db.from("subscriptions").select("status, provider, environment, started_at, current_period_end, auto_renew, subscription_plans(key, billing_interval, max_children)").order("started_at", { ascending: false }).limit(1),
    db.from("entitlements").select("active_until").eq("entitlement", "plus"),
    db.from("subscription_plans").select("key, billing_interval, trial_days, max_children").eq("active", true).order("billing_interval"),
  ]);
  const s = subs.data?.[0];
  const plan = s?.subscription_plans as unknown as { key: string; billing_interval: string; max_children: number } | null;
  const until = ent.data?.[0]?.active_until as string | undefined;
  const plus = (ent.data ?? []).some((e) => !e.active_until || Date.parse(e.active_until as string) > Date.now());
  return (
    <>
      <PageHeader title="Subscription" />
      <div className="grid gap-s6 lg:grid-cols-2">
        <Card title={plus ? "Plus" : "Basic"}>
          {s ? (
            <dl className="grid grid-cols-2 gap-s3 text-ui-body">
              <dt className="text-ui-text-muted">Plan</dt><dd>{plan?.billing_interval === "month" ? "Plus, monthly" : plan?.billing_interval === "year" ? "Plus, yearly" : plan?.key}</dd>
              <dt className="text-ui-text-muted">Status</dt><dd>{SUB_STATUS[s.status as string] ?? s.status}{s.environment === "sandbox" ? " (test)" : ""}</dd>
              <dt className="text-ui-text-muted">Bought through</dt><dd>{STORE[s.provider as string] ?? s.provider}</dd>
              <dt className="text-ui-text-muted">{s.auto_renew && s.status === "active" ? "Renews on" : "Ends on"}</dt><dd>{day(s.current_period_end as string, family.timezone)}</dd>
              <dt className="text-ui-text-muted">Children allowed</dt><dd>{plan?.max_children ?? "—"}</dd>
              {until && <><dt className="text-ui-text-muted">Plus works until</dt><dd>{day(until, family.timezone)}</dd></>}
            </dl>
          ) : <p className="text-ui-body">You&apos;re on Basic: one child, and everything not marked Plus.</p>}
          {s?.provider === "apple" && <a className="mt-s4 inline-block text-ui-primary underline" href="https://apps.apple.com/account/subscriptions" rel="noopener noreferrer" target="_blank">Manage in the App Store</a>}
          {s?.provider === "google" && <a className="mt-s4 inline-block text-ui-primary underline" href="https://play.google.com/store/account/subscriptions" rel="noopener noreferrer" target="_blank">Manage in Google Play</a>}
        </Card>
        <Card title="Plans">
          <ul className="flex flex-col gap-s3">{(plans.data ?? []).map((p) => <li key={p.key as string} className="rounded-md bg-ui-surface p-s4"><p className="text-ui-body-strong">{p.billing_interval === "month" ? "Plus, monthly" : p.billing_interval === "year" ? "Plus, yearly" : p.key}</p><p className="text-ui-small text-ui-text-muted">{p.trial_days ? `${p.trial_days}-day free trial · ` : ""}up to {p.max_children} children</p></li>)}</ul>
          <div className="mt-s4"><Notice>Buying on the web isn&apos;t connected yet, and nothing is charged here. Plans can be bought in the mobile app&apos;s store once payments launch.</Notice></div>
        </Card>
      </div>
    </>
  );
}
