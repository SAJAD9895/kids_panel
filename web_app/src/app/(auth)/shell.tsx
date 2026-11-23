import Link from "next/link";
import type { ReactNode } from "react";

/** The grown-up sign-in pages: one calm column, the app's name, then the step. */
export function AuthShell({ title, lead, children, foot }: { title: string; lead?: ReactNode; children: ReactNode; foot?: ReactNode }) {
  return (
    <main className="flex min-h-screen items-start justify-center bg-ui-surface px-s5 py-s9 md:items-center">
      <div className="w-full max-w-ui-form-w rounded-lg bg-ui-bg p-s7 shadow-card">
        <Link href="/" className="font-display text-ui-h3 text-ui-primary">Kids Learning</Link>
        <h1 className="mt-s5 text-ui-h1">{title}</h1>
        {lead && <p className="mt-s2 text-ui-body text-ui-text-muted">{lead}</p>}
        <div className="mt-s6 flex flex-col gap-s5">{children}</div>
        {foot && <div className="mt-s6 border-t border-ui-border pt-s5 text-ui-small text-ui-text-muted">{foot}</div>}
      </div>
    </main>
  );
}
export const NextField = ({ next }: { next?: string }) => (next ? <input type="hidden" name="next" value={next} /> : null);
