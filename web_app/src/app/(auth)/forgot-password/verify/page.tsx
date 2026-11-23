import Link from "next/link";
import { ActionForm, Submit, TextField } from "@/components/form";
import { resetPassword } from "../../actions";
import { AuthShell } from "../../shell";

export default async function ForgotVerify({ searchParams }: { searchParams: Promise<{ email?: string }> }) {
  const sp = await searchParams;
  return (
    <AuthShell title="Choose a new password" lead={<>If <strong>{sp.email}</strong> has an account, a code is on its way.</>}
      foot={<Link className="text-ui-primary underline" href="/forgot-password">Send another code</Link>}>
      <ActionForm action={resetPassword}>
        <input type="hidden" name="email" value={sp.email ?? ""} />
        <TextField name="code" label="6-digit code" required maxLength={6} />
        <TextField name="password" label="New password" type="password" required help="At least 10 characters, with a capital letter, a small letter and a number." />
        <Submit>Save and sign in</Submit>
      </ActionForm>
    </AuthShell>
  );
}
