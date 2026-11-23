import type { Metadata } from "next";
import { ActionForm, CheckField, Submit } from "@/components/form";
import { Card, EmptyState, PageHeader } from "@/components/ui";
import { dayTime } from "@/lib/format";
import { NOTICE_TYPES, noticeText } from "@/lib/notices";
import { listChildren, requireGrownUp } from "@/lib/session";
import { markAllRead, savePreferences } from "../actions";

export const metadata: Metadata = { title: "Notifications" };

export default async function Notifications() {
  const { db, family } = await requireGrownUp("/parents/notifications");
  const [kids, n, prefs] = await Promise.all([
    listChildren(db),
    db.from("notifications").select("id, type, params, created_at, read_at").eq("channel", "in_app").order("created_at", { ascending: false }).limit(50),
    db.from("notification_preferences").select("type, enabled").eq("user_id", family.userId).eq("channel", "in_app"),
  ]);
  const name = (id?: string) => kids.find((k) => k.id === id)?.nickname ?? "Your child";
  const off = new Set((prefs.data ?? []).filter((p) => !p.enabled).map((p) => p.type as string));
  const list = n.data ?? [];
  return (
    <>
      <PageHeader title="Notifications" subtitle="Notices from the app about your family. Email and push aren't connected yet." />
      <div className="grid gap-s6 lg:grid-cols-3">
        <Card title="Inbox" className="lg:col-span-2" actions={list.some((x) => !x.read_at) ? <ActionForm action={markAllRead}><Submit variant="secondary">Mark all as read</Submit></ActionForm> : undefined}>
          {list.length === 0 ? <EmptyState title="Nothing yet" /> : (
            <ul className="flex flex-col divide-y divide-ui-border">
              {list.map((x) => { const tx = noticeText(x.type as string, (x.params as Record<string, unknown>) ?? {}, name); return (
                <li key={x.id as string} className="flex gap-s3 py-s4">
                  <span className={`mt-s2 size-s2 shrink-0 rounded-pill ${x.read_at ? "bg-transparent" : "bg-ui-primary"}`} aria-label={x.read_at ? undefined : "Unread"} />
                  <div className="min-w-0"><p className="text-ui-body-strong">{tx.title}</p><p className="whitespace-pre-line text-ui-small text-ui-text-muted">{tx.body}</p><p className="text-ui-caption text-ui-text-muted">{dayTime(x.created_at as string, family.timezone)}</p></div>
                </li>); })}
            </ul>
          )}
        </Card>
        <Card title="What to tell me">
          <ActionForm action={savePreferences.bind(null, NOTICE_TYPES.map((t) => t[0]))}>
            {NOTICE_TYPES.map(([key, label, help]) => <CheckField key={key} name={key} label={label} help={help} initial={!off.has(key)} />)}
            <Submit>Save</Submit>
          </ActionForm>
        </Card>
      </div>
    </>
  );
}
