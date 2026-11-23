import { requireAdmin } from "@/lib/auth";
import { listPayments, listPlans, listSubscriptions, money } from "@/lib/data/business";
import { canAny } from "@/lib/permissions";
import { ActionForm, CheckField, Submit, TextField } from "@/components/form";
import { Card, date, EmptyState, Filters, Notice, PageHeader, Pagination, Table } from "@/components/ui";
import { savePlanAction } from "./actions";

const sel = "rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui";
const STATUSES = ["trialing", "active", "grace_period", "billing_retry", "paused", "cancelled", "expired", "refunded", "revoked"];

export default async function Billing({ searchParams }: { searchParams: Promise<{ status?: string; provider?: string; page?: string; ppage?: string }> }) {
  const sp = await searchParams;
  const { admin, db } = await requireAdmin(["billing.read"]);
  const [plans, subs, pays] = await Promise.all([listPlans(db), listSubscriptions(db, { status: sp.status, provider: sp.provider, page: Number(sp.page) || 1 }), listPayments(db, Number(sp.ppage) || 1)]);
  const manage = canAny(admin.permissions, ["billing.manage"]);
  return (
    <>
      <PageHeader title="Subscriptions" subtitle="Plans, subscriptions and payments as the stores and Stripe reported them." />
      <div className="mb-s6"><Notice>Nothing here charges, refunds or changes a subscription. Those happen in the App Store, Google Play or Stripe, and arrive through their webhooks (not connected in this build).</Notice></div>
      <div className="flex flex-col gap-s6">
        <Card title="Plans">
          <Table head={["Plan", "Billing", "Subscribers", "Settings"]}>
            {plans.map((p) => (
              <tr key={p.id}>
                <td className="font-mono">{p.key}</td><td>{p.interval}</td><td>{p.subscribers}</td>
                <td>{manage ? (
                  <ActionForm action={savePlanAction.bind(null, p.id)} className="!grid gap-s3 md:grid-cols-3">
                    <TextField name="trialDays" label="Trial days" type="number" min={0} max={31} initial={p.trialDays} />
                    <TextField name="maxChildren" label="Children" type="number" min={1} max={10} initial={p.maxChildren} />
                    <CheckField name="active" label="On sale" initial={p.active} />
                    <TextField name="apple" label="App Store product" initial={p.apple ?? ""} />
                    <TextField name="google" label="Google Play product" initial={p.google ?? ""} />
                    <TextField name="stripe" label="Stripe price" initial={p.stripe ?? ""} />
                    <div><Submit variant="secondary">Save plan</Submit></div>
                  </ActionForm>) : `${p.trialDays}-day trial · up to ${p.maxChildren} children · ${p.active ? "on sale" : "off sale"}`}</td>
              </tr>
            ))}
          </Table>
          <p className="mt-s3 text-ui-small text-ui-text-muted">Prices are set in each store and in Stripe, not here.</p>
        </Card>
        <Card title="Subscriptions">
          <Filters path="/billing">
            <label className="flex flex-col gap-s2"><span className="text-ui-small">Status</span><select name="status" defaultValue={sp.status ?? ""} className={sel}><option value="">All</option>{STATUSES.map((s) => <option key={s}>{s}</option>)}</select></label>
            <label className="flex flex-col gap-s2"><span className="text-ui-small">Store</span><select name="provider" defaultValue={sp.provider ?? ""} className={sel}><option value="">All</option>{["apple", "google", "stripe", "promo"].map((s) => <option key={s}>{s}</option>)}</select></label>
          </Filters>
          {subs.rows.length === 0 ? <EmptyState title="No subscriptions match" /> : (
            <Table head={["Account", "Plan", "Store", "Status", "Period ends", "Renews", "Environment"]}>
              {subs.rows.map((s) => <tr key={s.id}><td className="font-mono text-ui-small">{s.accountId.slice(0, 8)}</td><td>{s.plan}</td><td>{s.provider}</td><td>{s.status}</td><td>{date(s.periodEnd)}</td><td>{s.autoRenew ? "yes" : "no"}</td><td>{s.environment}</td></tr>)}
            </Table>
          )}
          <Pagination path="/billing" page={subs.page} pageSize={subs.pageSize} total={subs.total} params={{ status: sp.status, provider: sp.provider }} />
        </Card>
        <Card title="Payments">
          {pays.rows.length === 0 ? <EmptyState title="No payment records">Payments appear once store or Stripe webhooks are connected.</EmptyState> : (
            <Table head={["When", "Account", "Store", "Kind", "Amount", "Status"]}>
              {pays.rows.map((p) => <tr key={p.id}><td>{date(p.occurredAt)}</td><td className="font-mono text-ui-small">{p.accountId.slice(0, 8)}</td><td>{p.provider}</td><td>{p.kind}</td><td>{money(p.amountMinor, p.currency)}</td><td>{p.status}</td></tr>)}
            </Table>
          )}
        </Card>
      </div>
    </>
  );
}
