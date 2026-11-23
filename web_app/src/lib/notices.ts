// Parent notices: the switchable types and the words for each, as in the app
// (kids_app/lib/features/parents/domain/account.dart). Nicknames are filled in here, never stored in notices.
import { minutes } from "./format";

export const NOTICE_TYPES = [
  ["weekly_progress", "Weekly learning summary", "Every Monday: last week for each child"],
  ["goal_reached", "Goals reached", "When a child reaches a daily or weekly goal"],
  ["account_security", "Account activity", "Important changes, like a deleted profile"],
  ["deletion_scheduled", "Account deletion", "When the account is set to be deleted"],
  ["export_ready", "Data exports", "When a data export is ready"],
  ["subscription_changed", "Subscription changes", "Started, renewed, cancelled or ended"],
  ["billing_issue", "Payment problems", "When a store can't take a payment"],
  ["trial_ending", "Trial ending", "Two days before a free trial ends"],
] as const;

export const SUB_STATUS: Record<string, string> = { trialing: "Free trial", active: "Active", grace_period: "Payment problem (still active)", billing_retry: "Payment problem", paused: "Paused", cancelled: "Cancelled", expired: "Ended", refunded: "Refunded", revoked: "Revoked" };

export function noticeText(type: string, params: Record<string, unknown>, name: (id?: string) => string): { title: string; body: string } {
  switch (type) {
    case "weekly_progress": {
      const kids = (params.children as Record<string, unknown>[]) ?? [];
      return { title: "Last week's learning", body: kids.map((c) => `${name(c.childId as string)}: ${Number(c.learningDays ?? 0)} learning days, ${Number(c.activities ?? 0)} activities, ${minutes(Number(c.seconds ?? 0))}`).join("\n") };
    }
    case "goal_reached": return { title: `${name(params.childId as string)} reached ${params.period === "week" ? "this week's" : "today's"} goal`, body: "A bonus star was added. You can change goals under Goals and rewards." };
    case "export_ready": return { title: "Your data export is ready", body: "Download it from Privacy and data within 7 days." };
    case "deletion_scheduled": return { title: "Your account is set to be deleted", body: "You can cancel this from Privacy and data until the date shown there." };
    case "account_security": return { title: "A child profile was deleted", body: "If this wasn't you, sign out on all devices and contact support." };
    case "subscription_changed": return { title: "Your subscription changed", body: `Status: ${SUB_STATUS[String(params.status)] ?? params.status}.` };
    case "billing_issue": return { title: "There's a problem with a payment", body: "Check your payment method in the store you subscribed with." };
    case "trial_ending": return { title: "Your free trial ends soon", body: "Nothing to do if you want to keep Plus." };
    default: return { title: "Notice", body: "" };
  }
}
