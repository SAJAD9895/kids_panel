// Permissions come from the database (admin_role_permissions); this file only names them and
// decides which navigation items to show. The server re-checks every permission (RLS and the
// admin_api functions), so hiding a link is a convenience, not the protection.
export const PERMISSIONS = [
  "content.read", "content.write", "content.publish", "support.read", "support.act",
  "billing.read", "billing.manage", "privacy.act", "audit.read", "admin.manage",
] as const;
export type Permission = (typeof PERMISSIONS)[number];

export const ROLE_INFO: Record<string, { label: string; summary: string }> = {
  super_admin: { label: "Super admin", summary: "Everything, including admin users and settings" },
  content_publisher: { label: "Content manager", summary: "Writes, reviews, approves and publishes content" },
  content_editor: { label: "Content editor", summary: "Writes content and sends it for review" },
  support_agent: { label: "Support", summary: "Looks up families, restricts accounts, adds stars with a reason" },
  finance: { label: "Finance", summary: "Plans and billing records" },
  privacy_officer: { label: "Privacy officer", summary: "Data requests and the audit log" },
};

export type NavItem = { href: string; label: string; any: Permission[]; group: string };
export const NAV: NavItem[] = [
  { href: "/", label: "Dashboard", any: ["content.read", "support.read", "billing.read", "admin.manage"], group: "" },
  { href: "/content/review", label: "Review queue", any: ["content.read"], group: "Content" },
  { href: "/content/activities", label: "Activities and games", any: ["content.read"], group: "Content" },
  { href: "/content/courses", label: "Courses and lessons", any: ["content.read"], group: "Content" },
  { href: "/content/taxonomy", label: "Subjects and categories", any: ["content.read"], group: "Content" },
  { href: "/media", label: "Media library", any: ["content.read"], group: "Content" },
  { href: "/rewards", label: "Rewards", any: ["content.read"], group: "Content" },
  { href: "/families", label: "Families", any: ["support.read"], group: "People" },
  { href: "/privacy", label: "Data requests", any: ["privacy.act", "support.read"], group: "People" },
  { href: "/billing", label: "Subscriptions", any: ["billing.read"], group: "Business" },
  { href: "/settings/admins", label: "Admin users", any: ["admin.manage"], group: "Settings" },
  { href: "/settings/system", label: "System settings", any: ["admin.manage", "content.read"], group: "Settings" },
  { href: "/settings/audit", label: "Audit log", any: ["audit.read"], group: "Settings" },
];

export const canAny = (perms: readonly string[], any: readonly Permission[]) => any.some((p) => perms.includes(p));
export const navFor = (perms: readonly string[]) => NAV.filter((n) => canAny(perms, n.any));
