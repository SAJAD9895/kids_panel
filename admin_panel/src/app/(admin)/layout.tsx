import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { navFor, ROLE_INFO } from "@/lib/permissions";
import { signOut } from "./actions";
import { NavLinks } from "@/components/nav-links";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { admin } = await requireAdmin();
  const nav = navFor(admin.permissions);
  const roles = admin.roles.map((r) => ROLE_INFO[r]?.label ?? r).join(", ");
  return (
    <div className="min-h-screen bg-ui-bg lg:flex">
      <div className="bg-admin-sidebar lg:w-ui-sidebar-w lg:shrink-0">{/* full-height colour behind the sticky menu */}
      <aside className="bg-admin-sidebar text-admin-on-sidebar lg:sticky lg:top-0 lg:h-screen lg:overflow-y-auto">
        <div className="flex items-center justify-between p-s5">
          <Link href="/" className="text-ui-h3 font-display">Admin</Link>
          <span className="text-ui-caption text-admin-on-sidebar-muted lg:hidden">{admin.email}</span>
        </div>
        <NavLinks items={nav.map(({ href, label, group }) => ({ href, label, group }))} />
      </aside>
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center justify-end gap-s4 border-b border-ui-border px-s6 py-s3 text-ui-small">
          <span className="text-ui-text-muted">Signed in as <strong className="text-ui-text">{admin.email}</strong> · {roles || "no role"}</span>
          <form action={signOut}><button className="min-h-tap-ui rounded-md px-s3 text-ui-primary hover:bg-ui-primary-soft">Sign out</button></form>
        </div>
        <main className="mx-auto max-w-ui-content-max p-s6 lg:p-s8">{children}</main>
      </div>
    </div>
  );
}
