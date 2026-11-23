import Link from "next/link";
import { ActionForm, Submit, TextField } from "@/components/form";
import { verifyCode } from "../../actions";
import { AuthShell, NextField } from "../../shell";

export default async function SignInCode({ searchParams }: { searchParams: Promise<{ email?: string; next?: string }> }) {
  const sp = await searchParams;
  return (
    <AuthShell title="Check your email" lead={<>If <strong>{sp.email}</strong> has an account, we sent it a 6-digit code. It works for 10 minutes.</>}
      foot={<Link className="text-ui-primary underline" href="/sign-in">Use another email</Link>}>
      <ActionForm action={verifyCode.bind(null, "sign-in")}>
        <NextField next={sp.next} />
        <input type="hidden" name="email" value={sp.email ?? ""} />
        <TextField name="code" label="6-digit code" required maxLength={6} />
        <Submit>Sign in</Submit>
      </ActionForm>
    </AuthShell>
  );
}
