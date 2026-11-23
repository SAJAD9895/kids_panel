import Link from "next/link";
import { ActionForm, Submit, TextField } from "@/components/form";
import { requireFamily } from "@/lib/session";
import { setPassword } from "../../actions";
import { AuthShell } from "../../shell";

export default async function SetPassword() {
  await requireFamily("/sign-up/password");
  return (
    <AuthShell title="Add a password?" lead="Optional. With a password you can sign in without waiting for an email code. You can always use a code instead."
      foot={<Link className="text-ui-primary underline" href="/who">Skip for now</Link>}>
      <ActionForm action={setPassword}>
        <input type="hidden" name="next" value="/who" />
        <TextField name="password" label="Password" type="password" required help="At least 10 characters, with a capital letter, a small letter and a number." />
        <TextField name="confirm" label="The same password again" type="password" required />
        <Submit>Save password</Submit>
      </ActionForm>
    </AuthShell>
  );
}
