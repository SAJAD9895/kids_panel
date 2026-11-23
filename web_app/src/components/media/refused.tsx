import Link from "next/link";
import { LockIcon } from "../icons";

/** The server said no at launch (Plus, age, switched off, time up): say so kindly. */
export function MediaRefused({ message, back }: { type: string; message: string; back: { href: string; label: string } }) {
  return (
    <div className="flex flex-col items-center gap-s4 rounded-xl bg-kids-bg-alt p-s8 text-center" role="status">
      <span className="text-kids-ink-muted"><LockIcon className="size-kids-node" /></span>
      <p className="font-display text-kids-heading">{message}</p>
      <Link href={back.href} className="inline-flex min-h-tap-kids items-center rounded-xl bg-kids-surface px-s6 font-display text-kids-label shadow-kid-raised">{back.label}</Link>
    </div>
  );
}
