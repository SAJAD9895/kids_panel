// The admin UI kit, from the grown-up design tokens only (classes generated in app/theme.css).
import Link from "next/link";
import type { ReactNode } from "react";

type Variant = "primary" | "secondary" | "danger" | "ghost";
const variants: Record<Variant, string> = {
  primary: "bg-ui-primary text-ui-on-primary hover:bg-ui-primary-hover",
  secondary: "bg-ui-bg text-ui-text border border-ui-border-input hover:bg-ui-surface",
  danger: "bg-ui-danger text-ui-on-danger hover:opacity-90",
  ghost: "text-ui-primary hover:bg-ui-primary-soft",
};
const base = "inline-flex items-center justify-center gap-s3 rounded-md px-s5 min-h-tap-ui text-ui-body-strong disabled:opacity-50 disabled:cursor-not-allowed";

export function Button({ variant = "primary", className = "", ...p }: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return <button type={p.type ?? "submit"} className={`${base} ${variants[variant]} ${className}`} {...p} />;
}
export function LinkButton({ href, variant = "secondary", children }: { href: string; variant?: Variant; children: ReactNode }) {
  return <Link href={href} className={`${base} ${variants[variant]}`}>{children}</Link>;
}

export function PageHeader({ title, subtitle, actions, back }: { title: string; subtitle?: ReactNode; actions?: ReactNode; back?: { href: string; label: string } }) {
  return (
    <header className="mb-s7 flex flex-wrap items-end justify-between gap-s5">
      <div className="min-w-0">
        {back && <Link href={back.href} className="text-ui-small text-ui-primary hover:underline">← {back.label}</Link>}
        <h1 className="text-ui-h1 font-display break-words">{title}</h1>
        {subtitle && <p className="mt-s2 text-ui-body text-ui-text-muted">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-s3">{actions}</div>}
    </header>
  );
}

export function Card({ title, children, actions, className = "" }: { title?: string; children: ReactNode; actions?: ReactNode; className?: string }) {
  return (
    <section className={`rounded-lg border border-ui-border bg-ui-surface-raised p-s6 shadow-card ${className}`}>
      {(title || actions) && (
        <div className="mb-s5 flex flex-wrap items-center justify-between gap-s3">
          {title && <h2 className="text-ui-h3">{title}</h2>}
          {actions}
        </div>
      )}
      {children}
    </section>
  );
}

export function Stat({ label, value, href }: { label: string; value: number | string; href?: string }) {
  const body = (
    <div className="rounded-lg border border-ui-border bg-ui-surface-raised p-s5 shadow-card">
      <p className="text-ui-small text-ui-text-muted">{label}</p>
      <p className="text-ui-metric">{value}</p>
    </div>
  );
  return href ? <Link href={href} className="block rounded-lg hover:ring-2 hover:ring-ui-primary-soft">{body}</Link> : body;
}

const STATUS_STYLE: Record<string, string> = {
  draft: "bg-ui-surface text-ui-text-muted border border-ui-border",
  in_review: "bg-ui-warning-soft text-ui-warning-text",
  approved: "bg-ui-info-soft text-ui-info",
  published: "bg-ui-success-soft text-ui-success",
  active: "bg-ui-success-soft text-ui-success",
  ready: "bg-ui-success-soft text-ui-success",
  retired: "bg-ui-surface text-ui-text-muted border border-ui-border",
  suspended: "bg-ui-danger-soft text-ui-danger",
  failed: "bg-ui-danger-soft text-ui-danger",
  scheduled: "bg-ui-warning-soft text-ui-warning-text",
  pending_deletion: "bg-ui-warning-soft text-ui-warning-text",
};
export const STATUS_LABEL: Record<string, string> = {
  draft: "Draft", in_review: "In review", approved: "Approved", published: "Published", retired: "Archived",
  active: "Active", ready: "Ready", suspended: "Suspended", failed: "Failed", scheduled: "Scheduled",
  pending_deletion: "Being deleted", processing: "Processing", uploaded: "Uploaded", cancelled: "Cancelled",
  completed: "Completed", requested: "Requested", expired: "Expired",
};
export function StatusBadge({ status }: { status: string }) {
  return (
    <span className={`inline-flex rounded-pill px-s3 py-s1 text-ui-caption ${STATUS_STYLE[status] ?? "bg-ui-surface text-ui-text"}`}>
      {STATUS_LABEL[status] ?? status}
    </span>
  );
}

export function Notice({ tone = "info", children }: { tone?: "info" | "success" | "warning" | "danger"; children: ReactNode }) {
  const t = { info: "bg-ui-info-soft text-ui-info", success: "bg-ui-success-soft text-ui-success", warning: "bg-ui-warning-soft text-ui-warning-text", danger: "bg-ui-danger-soft text-ui-danger" }[tone];
  return <div role={tone === "danger" ? "alert" : "status"} className={`rounded-md p-s4 text-ui-body ${t}`}>{children}</div>;
}

export function EmptyState({ title, children, action }: { title: string; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="rounded-lg border border-dashed border-ui-border-input p-s8 text-center">
      <p className="text-ui-h3">{title}</p>
      {children && <p className="mt-s2 text-ui-body text-ui-text-muted">{children}</p>}
      {action && <div className="mt-s5 flex justify-center">{action}</div>}
    </div>
  );
}

export function Table({ head, children, empty }: { head: string[]; children: ReactNode; empty?: ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-lg border border-ui-border">
      <table className="w-full border-collapse text-left text-ui-body">
        <thead className="bg-ui-surface text-ui-small text-ui-text-muted">
          <tr>{head.map((h) => <th key={h} scope="col" className="px-s4 py-s3 font-semibold">{h}</th>)}</tr>
        </thead>
        <tbody className="[&>tr]:border-t [&>tr]:border-ui-border [&_td]:px-s4 [&_td]:py-s3 [&_td]:align-top">{children}</tbody>
      </table>
      {empty}
    </div>
  );
}

/** Previous / next links that keep the other search params. */
export function Pagination({ page, pageSize, total, params, path }: { page: number; pageSize: number; total: number; params: Record<string, string | undefined>; path: string }) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const href = (p: number) => {
    const q = new URLSearchParams(Object.entries({ ...params, page: String(p) }).filter(([, v]) => v) as [string, string][]);
    return `${path}?${q}`;
  };
  return (
    <nav aria-label="Pages" className="mt-s5 flex items-center justify-between gap-s3 text-ui-small text-ui-text-muted">
      <span>{total} in all · page {page} of {pages}</span>
      <span className="flex gap-s3">
        {page > 1 ? <Link className="text-ui-primary hover:underline" href={href(page - 1)}>← Previous</Link> : <span aria-hidden>← Previous</span>}
        {page < pages ? <Link className="text-ui-primary hover:underline" href={href(page + 1)}>Next →</Link> : <span aria-hidden>Next →</span>}
      </span>
    </nav>
  );
}

/** A GET form for search and filters (works without JavaScript). */
export function Filters({ children, path }: { children: ReactNode; path: string }) {
  return (
    <form action={path} className="mb-s5 flex flex-wrap items-end gap-s3" role="search">
      {children}
      <Button variant="secondary">Apply</Button>
    </form>
  );
}

export const dateTime = (s: string | null | undefined) =>
  s ? new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: "UTC" }).format(new Date(s)) + " UTC" : "—";
export const date = (s: string | null | undefined) =>
  s ? new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: "UTC" }).format(new Date(s)) : "—";
