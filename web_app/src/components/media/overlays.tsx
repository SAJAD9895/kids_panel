"use client";
import Link from "next/link";
import { StarIcon } from "../icons";

/** Shown when something is finished: the stars it earned (a star a day per activity). */
export function Celebration({ stars, next }: { stars: number; next: { href: string; label: string } }) {
  return (
    <div role="dialog" aria-modal="true" aria-labelledby="done-title" className="fixed inset-0 z-50 flex items-center justify-center bg-kids-scrim/60 p-s5">
      <div className="celebrate flex w-full max-w-ui-form-w flex-col items-center gap-s5 rounded-xl bg-kids-surface p-s8 text-center shadow-kid-raised">
        <span className="text-kids-star"><StarIcon className="size-kids-node" /></span>
        <h2 id="done-title" className="font-display text-kids-title">Well done!</h2>
        <p className="text-kids-body">{stars > 0 ? `You earned ${stars} ${stars === 1 ? "star" : "stars"}.` : "You finished it! (Today's star for this one is already yours.)"}</p>
        <Link href={next.href} autoFocus className="inline-flex min-h-tap-kids items-center rounded-xl bg-kids-me-fill px-s7 font-display text-kids-label shadow-kid-raised">{next.label}</Link>
      </div>
    </div>
  );
}

/** The daily watching / listening time is used up (the server decides, from the parent's limit). */
export function TimeUp({ back }: { back: string }) {
  return (
    <div role="dialog" aria-modal="true" aria-labelledby="timeup" className="fixed inset-0 z-50 flex items-center justify-center bg-kids-scrim/60 p-s5">
      <div className="flex w-full max-w-ui-form-w flex-col items-center gap-s5 rounded-xl bg-kids-surface p-s8 text-center shadow-kid-raised">
        <h2 id="timeup" className="font-display text-kids-title">That&apos;s all for today!</h2>
        <p className="text-kids-body">Time for something else. Games and lessons are still open.</p>
        <Link href={back} autoFocus className="inline-flex min-h-tap-kids items-center rounded-xl bg-kids-play-fill px-s7 font-display text-kids-label shadow-kid-raised">Play a game</Link>
      </div>
    </div>
  );
}
