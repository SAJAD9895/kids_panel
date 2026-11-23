import { LoginFlow } from "./login-flow";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ step?: string }> }) {
  const { step } = await searchParams;
  return (
    <main className="mx-auto flex min-h-screen max-w-ui-form-w flex-col justify-center gap-s7 p-s7">
      <div>
        <p className="text-ui-small text-ui-text-muted">Kids Learning Platform</p>
        <h1 className="text-ui-h1 font-display">Admin sign-in</h1>
        <p className="mt-s2 text-ui-body text-ui-text-muted">Staff only. Every admin uses an authenticator app (two-step sign-in).</p>
      </div>
      <LoginFlow startAtMfa={step === "mfa"} />
    </main>
  );
}
