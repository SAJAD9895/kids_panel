import Link from "next/link";
import type { ReactNode } from "react";
import type { Activity } from "@/lib/data/catalog";
import { hrefFor } from "@/lib/links";
import { LockIcon, StarIcon } from "./icons";
import { Thumb } from "./thumb";

export type Tone = "play" | "learn" | "watch" | "listen" | "me";
export const TONE: Record<Tone, { fill: string; soft: string; ink: string }> = {
  play: { fill: "bg-kids-play-fill", soft: "bg-kids-play-soft", ink: "text-kids-play-ink" },
  learn: { fill: "bg-kids-learn-fill", soft: "bg-kids-learn-soft", ink: "text-kids-learn-ink" },
  watch: { fill: "bg-kids-watch-fill", soft: "bg-kids-watch-soft", ink: "text-kids-watch-ink" },
  listen: { fill: "bg-kids-listen-fill", soft: "bg-kids-listen-soft", ink: "text-kids-listen-ink" },
  me: { fill: "bg-kids-me-fill", soft: "bg-kids-me-soft", ink: "text-kids-me-ink" },
};
export const toneOf = (a: Activity): Tone =>
  a.type === "video" ? "watch" : a.type === "song" || a.type === "story" || a.type === "audio_story" ? "listen" : a.type === "game" ? "play" : "learn";
export const KIND_WORD: Record<string, string> = { game: "Game", quiz: "Quiz", video: "Video", song: "Song", story: "Story", audio_story: "Audio story", printable: "Print", together: "Together" };

/** One activity: big picture, short title, what it is. The whole card is the link. */
export function ActivityCard({ a, locked = false, progress, done = false, href }: { a: Activity; locked?: boolean; progress?: number; done?: boolean; href?: string }) {
  const tone = TONE[toneOf(a)];
  return (
    <Link href={href ?? hrefFor(a)} className="group flex w-kids-card-w shrink-0 flex-col overflow-hidden rounded-xl bg-kids-surface shadow-kid-raised transition-transform hover:-translate-y-s1 active:translate-y-0 active:shadow-kid-pressed"
      aria-label={`${a.title}, ${KIND_WORD[a.type] ?? a.type}${locked ? ", locked: ask a grown-up" : ""}${done ? ", done" : ""}`}>
      <div className={`relative h-kids-card-art-h ${tone.soft}`}>
        <Thumb src={a.thumb} letter={a.title.slice(0, 1)} ink={tone.ink} />
        {locked && <span className="absolute right-s2 top-s2 rounded-pill bg-kids-scrim p-s2 text-kids-on-scrim"><LockIcon /></span>}
        {done && <span className="absolute right-s2 top-s2 rounded-pill bg-kids-surface p-s1 text-kids-star"><StarIcon /></span>}
        {progress !== undefined && progress > 0 && (
          <span className="absolute inset-x-0 bottom-0 h-s2 bg-kids-scrim/30" aria-hidden><span className={`block h-full ${tone.fill}`} style={{ width: `${Math.round(progress * 100)}%` }} /></span>
        )}
      </div>
      <div className="flex flex-col gap-s1 p-s3">
        <span className={`text-kids-caption font-bold ${tone.ink}`}>{KIND_WORD[a.type] ?? a.type}</span>
        <span className="line-clamp-2 text-kids-label font-bold leading-tight">{a.title}</span>
      </div>
    </Link>
  );
}

/** A row of cards: scrolls sideways on small screens, wraps into a grid on wide ones. */
export function Shelf({ title, children, more, empty }: { title: string; children: ReactNode; more?: { href: string; label: string }; empty?: string }) {
  const items = Array.isArray(children) ? children.filter(Boolean) : children;
  const none = Array.isArray(items) && items.length === 0;
  return (
    <section className="flex flex-col gap-s3" aria-label={title}>
      <div className="flex items-baseline justify-between gap-s4 px-s1">
        <h2 className="font-display text-kids-heading">{title}</h2>
        {more && <Link href={more.href} className="text-kids-label font-bold underline">{more.label}</Link>}
      </div>
      {none ? <p className="rounded-lg bg-kids-bg-alt p-s5 text-kids-body text-kids-ink-muted">{empty ?? "Nothing here yet."}</p> : (
        <div className="-mx-s4 flex snap-x gap-s4 overflow-x-auto px-s4 pb-s3 xl:mx-0 xl:grid xl:grid-cols-[repeat(auto-fill,minmax(var(--spacing-kids-card-w),1fr))] xl:overflow-visible xl:px-0 [&>*]:snap-start xl:[&>*]:w-auto">
          {items}
        </div>
      )}
    </section>
  );
}

/** Big round-cornered button for small fingers (≥ 64 px tall). */
export function KidButton({ children, tone = "learn", className = "", ...p }: React.ButtonHTMLAttributes<HTMLButtonElement> & { tone?: Tone }) {
  return <button {...p} className={`inline-flex min-h-tap-kids items-center justify-center gap-s2 rounded-xl px-s6 font-display text-kids-label shadow-kid-raised active:shadow-kid-pressed disabled:opacity-50 ${TONE[tone].fill} text-kids-ink ${className}`}>{children}</button>;
}
export function KidLink({ children, tone = "learn", href, className = "" }: { children: ReactNode; tone?: Tone; href: string; className?: string }) {
  return <Link href={href} className={`inline-flex min-h-tap-kids items-center justify-center gap-s2 rounded-xl px-s6 font-display text-kids-label shadow-kid-raised active:shadow-kid-pressed ${TONE[tone].fill} text-kids-ink ${className}`}>{children}</Link>;
}

export function Stars({ n, label = "stars" }: { n: number; label?: string }) {
  return <span className="inline-flex items-center gap-s1 rounded-pill bg-kids-surface px-s3 py-s1 font-display text-kids-label shadow-kid-raised" aria-label={`${n} ${label}`}><span className="text-kids-star"><StarIcon /></span>{n}</span>;
}

export function ProgressBar({ value, tone = "learn", label }: { value: number; tone?: Tone; label: string }) {
  const pct = Math.round(Math.max(0, Math.min(1, value)) * 100);
  return (
    <div role="progressbar" aria-label={label} aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100} className="h-s3 w-full overflow-hidden rounded-pill bg-kids-line">
      <div className={`h-full rounded-pill ${TONE[tone].fill}`} style={{ width: `${pct}%` }} />
    </div>
  );
}
