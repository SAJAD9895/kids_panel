"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

const ITEMS = [
  { href: "/parents", label: "Overview" },
  { href: "/parents/children", label: "Children" },
  { href: "/parents/notifications", label: "Notifications" },
  { href: "/parents/subscription", label: "Subscription" },
  { href: "/parents/privacy", label: "Privacy and data" },
  { href: "/parents/settings", label: "Account settings" },
];

/** Grown-up navigation: a sidebar on wide screens; a Menu button on tablets and phones. */
export function ParentNav() {
  const path = usePathname();
  const [open, setOpen] = useState(false);
  const active = (h: string) => (h === "/parents" ? path === h : path.startsWith(h));
  return (
    <nav aria-label="Grown-up pages">
      <button type="button" aria-expanded={open} onClick={() => setOpen((o) => !o)} className="mx-s5 mb-s3 min-h-tap-ui rounded-md border border-ui-border-input px-s4 lg:hidden">Menu</button>
      <ul className={`${open ? "flex" : "hidden"} flex-col gap-s1 px-s3 pb-s4 lg:flex`}>
        {ITEMS.map((i) => (
          <li key={i.href}><Link href={i.href} aria-current={active(i.href) ? "page" : undefined} onClick={() => setOpen(false)}
            className={`flex min-h-tap-ui items-center rounded-md px-s4 ${active(i.href) ? "bg-ui-primary-soft font-semibold text-ui-primary" : "hover:bg-ui-surface"}`}>{i.label}</Link></li>
        ))}
      </ul>
    </nav>
  );
}
