// Subscriptions and payments (read with billing.read; plans edited with billing.manage).
// Nothing here charges, refunds or changes a subscription: those come from the stores / Stripe.
import { AdminError, must, mustOne } from "../errors";
import { type Db, type Page, range, type Row } from "./db";

export type Plan = { id: string; key: string; interval: string; trialDays: number; maxChildren: number; active: boolean; apple: string | null; google: string | null; stripe: string | null; subscribers: number };
export async function listPlans(db: Db): Promise<Plan[]> {
  return must(await db.from("subscription_plans").select("*, subscriptions(count)").order("key")).map((p: Row) => ({
    id: p.id, key: p.key, interval: p.billing_interval, trialDays: p.trial_days, maxChildren: p.max_children, active: p.active,
    apple: p.apple_product_id, google: p.google_product_id, stripe: p.stripe_price_id, subscribers: p.subscriptions?.[0]?.count ?? 0,
  }));
}
export type PlanInput = { trialDays: number; maxChildren: number; active: boolean; apple: string; google: string; stripe: string };
export async function savePlan(db: Db, id: string, v: PlanInput) {
  if (v.trialDays < 0 || v.trialDays > 31) throw new AdminError("Trial days are 0–31.");
  if (v.maxChildren < 1 || v.maxChildren > 10) throw new AdminError("Children are 1–10.");
  const prod = (s: string) => (s.trim() ? s.trim() : null);
  for (const s of [v.apple, v.google, v.stripe]) if (s.trim() && !/^[\w.:-]{3,100}$/.test(s.trim())) throw new AdminError("Product ids are letters, numbers, dots, dashes and _.");
  mustOne(await db.from("subscription_plans").update({
    trial_days: v.trialDays, max_children: v.maxChildren, active: v.active,
    apple_product_id: prod(v.apple), google_product_id: prod(v.google), stripe_price_id: prod(v.stripe),
  }).eq("id", id).select("id"));
}

export type Sub = { id: string; accountId: string; plan: string; provider: string; status: string; environment: string; periodEnd: string | null; autoRenew: boolean; startedAt: string };
export async function listSubscriptions(db: Db, f: { status?: string; provider?: string; page?: number }): Promise<Page<Sub>> {
  const r = range(f.page ?? 1);
  let q = db.from("subscriptions").select("id, account_id, provider, status, environment, current_period_end, auto_renew, started_at, subscription_plans(key)", { count: "exact" });
  if (f.status) q = q.eq("status", f.status);
  if (f.provider) q = q.eq("provider", f.provider);
  const res = await q.order("started_at", { ascending: false }).range(r.from, r.to);
  return {
    rows: must(res).map((s: Row) => ({ id: s.id, accountId: s.account_id, plan: s.subscription_plans?.key ?? "?", provider: s.provider, status: s.status,
      environment: s.environment, periodEnd: s.current_period_end, autoRenew: s.auto_renew, startedAt: s.started_at })),
    total: res.count ?? 0, page: r.page, pageSize: r.size,
  };
}
export type Payment = { id: string; accountId: string; provider: string; kind: string; amountMinor: number; currency: string; status: string; occurredAt: string };
export async function listPayments(db: Db, page = 1): Promise<Page<Payment>> {
  const r = range(page);
  const res = await db.from("payments").select("*", { count: "exact" }).order("occurred_at", { ascending: false }).range(r.from, r.to);
  return {
    rows: must(res).map((p: Row) => ({ id: p.id, accountId: p.account_id, provider: p.provider, kind: p.kind, amountMinor: Number(p.amount_minor), currency: p.currency, status: p.status, occurredAt: p.occurred_at })),
    total: res.count ?? 0, page: r.page, pageSize: r.size,
  };
}
export const money = (minor: number, currency: string) =>
  new Intl.NumberFormat("en-GB", { style: "currency", currency }).format(minor / 100);
