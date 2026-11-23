# Subscription management (P06)

Phase 13, 2026-11-22. `/parents/subscription`.

**No payment integration is faked.** The screen shows what the billing tables hold (Phase 5 schema), links to the stores where that is a real action, and says plainly when an action needs a store or Stripe connection this build doesn't have.

## Data (read under RLS: household only)

| shown | source |
| --- | --- |
| plan (Plus monthly / yearly), children allowed | `subscriptions` → `subscription_plans` (newest subscription) |
| status (Free trial, Active, Payment problem, Paused, Cancelled, Ended, Refunded, Revoked) | `subscriptions.status` |
| bought through (App Store, Google Play, Web, Code) | `subscriptions.provider` |
| started; "Renews on" (active + auto-renew) or "Ends on" | `started_at`, `current_period_end`, `auto_renew` |
| Plus works until | `entitlements.active_until` (what the app actually uses for access) |
| "Test subscription" tag | `environment = 'sandbox'` |
| a payment-problem warning | status `billing_retry` or `grace_period` |
| plans to choose from (Basic families) | `subscription_plans` (active), with trial length and children; **no price**, because store prices come from the store at purchase |

These rows are written only by the billing service (webhooks and store verification), which isn't built yet. In the seed, Alice's family has a sandbox subscription from a code.

## Actions

| action | what it does | functional? |
| --- | --- | --- |
| Open App Store / Google Play subscriptions | opens the store's own subscription page (`apps.apple.com/account/subscriptions`, `play.google.com/store/account/subscriptions`), where changes and cancellations happen | **yes** (a link; the store does the work) |
| Plus from a code | explains it ends by itself on its date, with nothing to cancel and no charge | yes (information) |
| Manage web billing (Stripe Customer Portal) | dialog: not connected | **no**, needs Stripe keys and a portal session route |
| Choose a plan (upgrade) | dialog: not connected, nothing charged | **no**, needs StoreKit / Play Billing (or RevenueCat) and `billing/checkout` |
| Restore purchases | dialog: not connected | **no**, needs the store SDK |
| Check status again | reloads the subscription | yes |

The labels say "(not connected yet)", so no control pretends to work.

## Notifications

`subscriptions` triggers send:
- **`subscription_changed`** for a new status;
- **`billing_issue`** for `billing_retry` or `grace_period`.

`queue_due_notifications` sends **`trial_ending`** two days before a trial ends. All of them respect the parent's preferences (tested in D1).

## To finish payments (not in this phase)

1. **Stores.** Apple and Google products. Then StoreKit 2 / Play Billing, or RevenueCat, in the app.
2. **Store webhooks.** `billing/webhooks/*` Edge Functions, writing to `billing_webhook_events` (replay-safe) and then `subscriptions` and `entitlements`.
3. **Web checkout.** Stripe Checkout and the Customer Portal, for the web.
4. **The rest.** Promo redemption (`billing/redeem`), and the P07 paywall.
