import Link from "next/link";
import { ActionForm, Submit, TextField } from "@/components/form";
import { sendRecovery } from "../actions";
import { AuthShell } from "../shell";

export default function Forgot() {
  return (
    <AuthShell title="Reset your password" lead="We'll email a 6-digit code to the address on your account."
      foot={<Link className="text-ui-primary underline" href="/sign-in">Back to sign-in</Link>}>
      <ActionForm action={sendRecovery}>
        <TextField name="email" label="Email" type="email" required />
        <Submit>Send a code</Submit>
      </ActionForm>
    </AuthShell>
  );
}
