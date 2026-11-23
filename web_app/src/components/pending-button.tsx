"use client";
// A submit button for plain <form action={serverAction}> forms. A server action can't move to the
// next page before the server answers, so the tapped button shows it's working straight away
// (and can't be tapped twice). `pendingLabel` swaps the text; without it the content stays and pulses.
import type { ButtonHTMLAttributes, ReactNode } from "react";
import { useFormStatus } from "react-dom";

export function PendingButton({ children, pendingLabel, className = "", ...rest }:
  ButtonHTMLAttributes<HTMLButtonElement> & { children: ReactNode; pendingLabel?: ReactNode }) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" {...rest} disabled={pending || rest.disabled} aria-busy={pending} data-pending={pending || undefined}
      className={`${className} data-[pending]:cursor-progress data-[pending]:opacity-70 ${pendingLabel ? "" : "data-[pending]:animate-pulse motion-reduce:data-[pending]:animate-none"}`}>
      {pending && pendingLabel ? pendingLabel : children}
    </button>
  );
}
