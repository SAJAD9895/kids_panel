"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

type Item = { href: string; label: string; group: string };

/** Sidebar on wide screens; a menu button on tablets and phones. */
export function NavLinks({ items }: { items: Item[] }) {
  const path = usePathname();
  const [open, setOpen] = useState(false);
  const groups = [...new Set(items.map((i) => i.group))];
  const active = (href: string) => (href === "/" ? path === "/" : path.startsWith(href));
  return (
    <nav aria-label="Admin">
      <button type="button" onClick={() => setOpen(!open)} aria-expanded={open}
        className="mx-s5 mb-s3 min-h-tap-ui rounded-md border border-admin-on-sidebar-muted px-s4 lg:hidden">Menu</button>
      <div className={`${open ? "block" : "hidden"} pb-s5 lg:block`}>
        {groups.map((g) => (
          <div key={g} className="mt-s3">
            {g && <p className="px-s5 py-s2 text-ui-caption uppercase text-admin-on-sidebar-muted">{g}</p>}
            {items.filter((i) => i.group === g).map((i) => (
              <Link key={i.href} href={i.href} onClick={() => setOpen(false)} aria-current={active(i.href) ? "page" : undefined}
                className={`mx-s3 flex min-h-tap-ui items-center rounded-md px-s4 text-ui-body hover:bg-admin-sidebar-active ${active(i.href) ? "bg-admin-sidebar-active font-semibold" : ""}`}>
                {i.label}
              </Link>
            ))}
          </div>
        ))}
      </div>
    </nav>
  );
}
