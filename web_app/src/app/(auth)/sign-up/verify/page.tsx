import Link from "next/link";
import { ActionForm, Submit, TextField } from "@/components/form";
import { verifyCode } from "../../actions";
import { AuthShell } from "../../shell";

export default async function SignUpVerify({ searchParams }: { searchParams: Promise<{ email?: string }> }) {
  const sp = await searchParams;
  return (
    <AuthShell title="Check your email" lead={<>Step 2 of 3. We sent a 6-digit code to <strong>{sp.email}</strong>. It works for 10 minutes.</>}
      foot={<Link className="text-ui-primary underline" href="/sign-up">Use another email</Link>}>
      <ActionForm action={verifyCode.bind(null, "sign-up")}>
        <input type="hidden" name="email" value={sp.email ?? ""} />
        <TextField name="code" label="6-digit code" required maxLength={6} />
        <Submit>Continue</Submit>
      </ActionForm>
    </AuthShell>
  );
}
