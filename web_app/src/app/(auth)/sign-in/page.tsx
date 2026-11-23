import Link from "next/link";
import type { Metadata } from "next";
import { ActionForm, Submit, TextField } from "@/components/form";
import { Notice } from "@/components/ui";
import { sendCode, signInWithPassword } from "../actions";
import { AuthShell, NextField } from "../shell";

export const metadata: Metadata = { title: "Sign in" };

export default async function SignIn({ searchParams }: { searchParams: Promise<{ next?: string; signedOut?: string; reset?: string }> }) {
  const sp = await searchParams;
  return (
    <AuthShell title="Welcome back" lead="Sign in to play, or to see how your children are doing."
      foot={<>New here? <Link className="text-ui-primary underline" href="/sign-up">Create a family account</Link></>}>
      {sp.signedOut && <Notice tone="success">You&apos;re signed out.</Notice>}
      <ActionForm action={signInWithPassword}>
        <NextField next={sp.next} />
        <TextField name="email" label="Email" type="email" required />
        <TextField name="password" label="Password" type="password" required />
        <Submit>Sign in</Submit>
        <Link href="/forgot-password" className="text-ui-small text-ui-primary underline">Forgot your password?</Link>
      </ActionForm>
      <details className="rounded-md border border-ui-border p-s4">
        <summary className="cursor-pointer text-ui-body-strong">No password? Get a code by email</summary>
        <ActionForm action={sendCode.bind(null, "sign-in")} className="mt-s4">
          <NextField next={sp.next} />
          <TextField name="email" label="Email" type="email" required />
          <Submit variant="secondary">Email me a code</Submit>
        </ActionForm>
      </details>
    </AuthShell>
  );
}
