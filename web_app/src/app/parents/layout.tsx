import Link from "next/link";
import { headers } from "next/headers";
import { requireGrownUp } from "@/lib/session";
import { signOut } from "../(auth)/actions";
import { backToKids } from "../zone-actions";
import { ParentNav } from "./nav";
import { PendingButton } from "@/components/pending-button";

export default async function ParentsLayout({ children }: { children: React.ReactNode }) {
  const path = (await headers()).get("x-pathname") ?? "/parents";
  const { family } = await requireGrownUp(path);
  return (
    <div className="min-h-screen bg-ui-bg lg:flex">
      <aside className="border-b border-ui-border bg-ui-surface lg:sticky lg:top-0 lg:h-screen lg:w-ui-sidebar-w lg:shrink-0 lg:border-b-0 lg:border-r">
        <div className="flex items-center justify-between gap-s3 p-s5">
          <Link href="/parents" className="font-display text-ui-h3 text-ui-primary">Kids Learning</Link>
          <span className="text-ui-caption text-ui-text-muted lg:hidden">Grown-ups</span>
        </div>
        <ParentNav />
        <div className="hidden flex-col gap-s2 px-s5 pb-s5 lg:flex">
          <form action={backToKids}><PendingButton pendingLabel="Opening…" className="min-h-tap-ui w-full rounded-md bg-ui-primary px-s4 text-ui-on-primary">Back to playing</PendingButton></form>
        </div>
      </aside>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center justify-end gap-s3 border-b border-ui-border px-s5 py-s2 text-ui-small">
          <span className="min-w-0 truncate text-ui-text-muted">Signed in as <strong className="text-ui-text">{family.email}</strong></span>
          <form action={backToKids} className="lg:hidden"><PendingButton pendingLabel="Opening…" className="min-h-tap-ui rounded-md px-s3 text-ui-primary">Back to playing</PendingButton></form>
          <form action={signOut}><PendingButton pendingLabel="Signing out…" className="min-h-tap-ui rounded-md px-s3 text-ui-primary hover:bg-ui-primary-soft">Sign out</PendingButton></form>
        </div>
        <main className="mx-auto max-w-ui-content-max p-s5 md:p-s7">{children}</main>
      </div>
    </div>
  );
}
