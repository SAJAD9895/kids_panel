import type { Metadata } from "next";
import { ActionForm, ConfirmAction, Submit, TextField } from "@/components/form";
import { PendingButton } from "@/components/pending-button";
import { Card, Notice, PageHeader, Table } from "@/components/ui";
import { day, dayTime } from "@/lib/format";
import { listChildren, requireGrownUp } from "@/lib/session";
import { cancelDeletion, downloadExport, requestExport, scheduleDeletion } from "../actions";

export const metadata: Metadata = { title: "Privacy and data" };
const CONSENT: Record<string, string> = { terms: "Terms of use", privacy_policy: "Privacy policy", child_data_collection: "Collecting your child's learning progress", marketing: "Tips and news", push: "Push notifications" };

export default async function Privacy() {
  const { db, family } = await requireGrownUp("/parents/privacy");
  const [kids, consents, exports, deletions] = await Promise.all([
    listChildren(db),
    db.from("parental_consents").select("consent_type, policy_version, method, granted_at, revoked_at").order("granted_at"),
    db.from("data_export_requests").select("id, status, child_id, created_at, expires_at").order("created_at", { ascending: false }).limit(10),
    db.from("deletion_requests").select("id, scope, status, scheduled_for").eq("scope", "account").order("created_at", { ascending: false }).limit(3),
  ]);
  const pending = (deletions.data ?? []).find((d) => d.status === "scheduled");
  const owner = family.role === "owner";
  return (
    <>
      <PageHeader title="Privacy and data" subtitle="What you agreed to, a copy of your family's data, and deleting the account." />
      <div className="flex flex-col gap-s6">
        <Card title="Your consents">
          <Table head={["Consent", "Version", "How", "Given", "Withdrawn"]}>
            {(consents.data ?? []).map((c, i) => <tr key={i}><td>{CONSENT[c.consent_type as string] ?? c.consent_type}</td><td>{c.policy_version}</td><td>{c.method === "email_plus" ? "Checkbox + confirmed email" : "Checkbox"}</td><td>{day(c.granted_at as string, family.timezone)}</td><td>{c.revoked_at ? day(c.revoked_at as string, family.timezone) : "—"}</td></tr>)}
          </Table>
        </Card>
        <Card title="Download your data">
          <p className="mb-s4 text-ui-body text-ui-text-muted">A file (JSON) with everything we keep: for one child, or the whole account. Up to 5 a day. If you signed in a while ago you&apos;ll be asked to sign in again.</p>
          <ActionForm action={requestExport} className="!flex-row flex-wrap items-end">
            <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">What</span>
              <select name="childId" className="min-h-tap-ui rounded-md border border-ui-border-input bg-ui-bg px-s3">
                <option value="">The whole account</option>{kids.map((k) => <option key={k.id} value={k.id}>{k.nickname}&apos;s data</option>)}
              </select>
            </label>
            <Submit>Make an export</Submit>
          </ActionForm>
          {(exports.data ?? []).length > 0 && (
            <div className="mt-s5"><Table head={["Asked", "For", "Status", "Kept until", ""]}>
              {(exports.data ?? []).map((e) => (
                <tr key={e.id as string}><td>{dayTime(e.created_at as string, family.timezone)}</td><td>{e.child_id ? kids.find((k) => k.id === e.child_id)?.nickname ?? "A child" : "Whole account"}</td><td>{e.status}</td><td>{day(e.expires_at as string, family.timezone)}</td>
                  <td>{e.status === "ready" && <form action={downloadExport.bind(null, e.id as string)}><PendingButton pendingLabel="Preparing…" className="min-h-tap-ui text-ui-primary underline">Download</PendingButton></form>}</td></tr>
              ))}
            </Table></div>
          )}
        </Card>
        <Card title="Delete the account">
          {pending ? (
            <>
              <Notice tone="warning">The account will be deleted on {day(pending.scheduled_for as string, family.timezone)}: every child, all progress, and your sign-in.</Notice>
              <div className="mt-s4"><ConfirmAction action={cancelDeletion.bind(null, pending.id as string)} label="Keep my account" title="Keep the account?" message="Nothing will be deleted." confirm="Keep it" /></div>
            </>
          ) : owner ? (
            <ActionForm action={scheduleDeletion}>
              <p className="text-ui-body text-ui-text-muted">Deletes everything after 7 days; you can change your mind until then. Subscriptions bought in a store must be cancelled in that store.</p>
              <TextField name="confirm" label="Type DELETE to confirm" required />
              <Submit variant="danger">Delete in 7 days</Submit>
            </ActionForm>
          ) : <p className="text-ui-body">Only the account owner can delete the account.</p>}
        </Card>
      </div>
    </>
  );
}
