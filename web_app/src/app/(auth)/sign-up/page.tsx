import Link from "next/link";
import type { Metadata } from "next";
import { ActionForm, Submit, TextField } from "@/components/form";
import { sendCode } from "../actions";
import { AuthShell } from "../shell";

export const metadata: Metadata = { title: "Create a family account" };

export default function SignUp() {
  return (
    <AuthShell title="Create a family account" lead="Step 1 of 3: your email. We'll send a code to check it's yours. Children never need an email or a password."
      foot={<>Already have an account? <Link className="text-ui-primary underline" href="/sign-in">Sign in</Link></>}>
      <ActionForm action={sendCode.bind(null, "sign-up")}>
        <TextField name="email" label="Your email (a grown-up's)" type="email" required />
        <Submit>Send me a code</Submit>
      </ActionForm>
    </AuthShell>
  );
}
