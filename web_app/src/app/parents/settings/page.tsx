import type { Metadata } from "next";
import { ActionForm, CheckField, Submit, TextField } from "@/components/form";
import { Card, PageHeader } from "@/components/ui";
import { requireGrownUp } from "@/lib/session";
import { signOut } from "../../(auth)/actions";
import { changePassword } from "../actions";

export const metadata: Metadata = { title: "Account settings" };

export default async function Settings() {
  const { family } = await requireGrownUp("/parents/settings");
  return (
    <>
      <PageHeader title="Account settings" />
      <div className="grid gap-s6 lg:grid-cols-2">
        <Card title="Your account">
          <dl className="grid grid-cols-2 gap-s3 text-ui-body"><dt className="text-ui-text-muted">Email</dt><dd className="break-all">{family.email}</dd><dt className="text-ui-text-muted">Time zone</dt><dd>{family.timezone}</dd><dt className="text-ui-text-muted">Role</dt><dd>{family.role === "owner" ? "Owner" : "Co-parent"}</dd></dl>
        </Card>
        <Card title="Password">
          <ActionForm action={changePassword} resetOnOk>
            <TextField name="password" label="New password" type="password" required help="At least 10 characters, with a capital letter, a small letter and a number." />
            <TextField name="confirm" label="The same again" type="password" required />
            <Submit>Change password</Submit>
          </ActionForm>
        </Card>
        <Card title="Sign out">
          <form action={signOut} className="flex flex-col gap-s4">
            <CheckField name="everywhere" label="Also sign out on every other device" />
            <div><Submit variant="secondary">Sign out</Submit></div>
          </form>
        </Card>
      </div>
    </>
  );
}
