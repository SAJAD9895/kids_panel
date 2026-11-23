import Link from "next/link";
import { signOut } from "../(admin)/actions";

const WHY: Record<string, string> = {
  not_admin: "This account isn't an admin. Ask a super admin to add you.",
  suspended: "Your admin access is suspended.",
  permission: "Your role doesn't include this part of the admin.",
};

export default async function NoAccess({ searchParams }: { searchParams: Promise<{ reason?: string }> }) {
  const { reason = "not_admin" } = await searchParams;
  return (
    <main className="mx-auto flex min-h-screen max-w-ui-form-w flex-col justify-center gap-s5 p-s7">
      <h1 className="text-ui-h1 font-display">No access</h1>
      <p className="text-ui-body">{WHY[reason] ?? WHY.not_admin}</p>
      <div className="flex gap-s3">
        {reason === "permission" && <Link href="/" className="min-h-tap-ui rounded-md border border-ui-border-input px-s5 py-s3">Back to the dashboard</Link>}
        <form action={signOut}><button className="min-h-tap-ui rounded-md bg-ui-primary px-s5 text-ui-on-primary">Sign out</button></form>
      </div>
    </main>
  );
}
