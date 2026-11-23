"use client";
/* eslint-disable @next/next/no-img-element -- page art via short-lived URLs (already sized webp) */
import { useCallback, useEffect, useRef, useState } from "react";
import { t as text } from "@/lib/format";
import type { LaunchFile } from "@/lib/data/launch";
import type { Resume } from "@/lib/rules";
import { BackIcon, NextIcon, SpeakerIcon } from "../icons";
import { Celebration, TimeUp } from "./overlays";
import { localResume, newer, useMediaSession } from "./use-media-session";

type Props = { childId: string; activityId: string; title: string; contentVersion: number; stepId?: string | null; files: LaunchFile[]; resume: Resume | null; done: { href: string; label: string } };

/** Illustrated stories: one page at a time, big arrows, arrow keys or a swipe; "Read to me" plays
 * the page's narration when there is one, otherwise the browser reads the words aloud. */
export function StoryReader(p: Props) {
  const pages = p.files.filter((f) => f.role === "page_image").sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
  const audio = new Map(p.files.filter((f) => f.role === "page_audio").map((f) => [f.position ?? 0, f]));
  const ms = useMediaSession({ childId: p.childId, activityId: p.activityId, contentVersion: p.contentVersion, stepId: p.stepId, section: "listen" });
  const [page, setPage] = useState(0);
  const [restored, setRestored] = useState<number | null>(null);
  const started = useRef(false);
  const swipe = useRef<number | null>(null);
  const voice = useRef<HTMLAudioElement>(null);
  const count = pages.length;

  useEffect(() => {
    const r = newer(p.resume, localResume(p.childId, p.activityId));
    if (r?.page != null && r.page > 0 && r.page < count - 1) { setPage(r.page); setRestored(r.page); }
  }, [p.resume, p.childId, p.activityId, count]);
  useEffect(() => {
    if (!started.current && count) { started.current = true; ms.start(); }
    ms.save({ page, pages: count });
  }, [page, count, ms]);
  useEffect(() => { const id = setInterval(ms.tick, 1000); return () => clearInterval(id); }, [ms]);

  const go = useCallback((d: number) => {
    window.speechSynthesis?.cancel(); voice.current?.pause();
    setPage((n) => Math.max(0, Math.min(count - 1, n + d)));
  }, [count]);
  useEffect(() => {
    const k = (e: KeyboardEvent) => { if (e.key === "ArrowRight") go(1); if (e.key === "ArrowLeft") go(-1); };
    window.addEventListener("keydown", k);
    return () => window.removeEventListener("keydown", k);
  }, [go]);

  if (!count) return <p className="text-kids-body">This story isn&apos;t ready yet.</p>;
  const cur = pages[page];
  const words = text(cur.text);
  const readAloud = () => {
    const a = audio.get(cur.position ?? page);
    if (a && voice.current) { voice.current.src = a.url; void voice.current.play(); return; }
    if (words && "speechSynthesis" in window) { window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance(words); u.rate = 0.9; window.speechSynthesis.speak(u); }
  };
  const last = page === count - 1;
  return (
    <div className="flex flex-col gap-s4">
      <figure className="flex flex-col overflow-hidden rounded-xl bg-kids-surface shadow-kid-raised lg:flex-row"
        onPointerDown={(e) => { swipe.current = e.clientX; }}
        onPointerUp={(e) => { if (swipe.current !== null && Math.abs(e.clientX - swipe.current) > 60) go(e.clientX < swipe.current ? 1 : -1); swipe.current = null; }}>
        <img src={cur.url} alt={words ? `Picture: ${words}` : `Page ${page + 1}`} className="aspect-square w-full touch-pan-y select-none object-cover lg:w-1/2" draggable={false} />
        <figcaption className="flex flex-1 items-center p-s6 font-reading text-kids-reading-lg leading-snug" aria-live="polite">{words}</figcaption>
      </figure>
      <audio ref={voice} preload="none" />
      <div className="flex items-center justify-between gap-s3">
        <button onClick={() => go(-1)} disabled={page === 0} aria-label="Previous page" className="flex size-tap-kids-xl items-center justify-center rounded-pill bg-kids-surface shadow-kid-raised disabled:opacity-40"><BackIcon className="size-icon-kids" /></button>
        <div className="flex flex-col items-center gap-s2">
          <button onClick={readAloud} className="flex min-h-tap-kids items-center gap-s2 rounded-xl bg-kids-listen-fill px-s5 font-display text-kids-label shadow-kid-raised"><SpeakerIcon />Read to me</button>
          <span className="text-kids-caption text-kids-ink-muted" aria-live="polite">Page {page + 1} of {count}</span>
        </div>
        {last ? (
          <button onClick={() => void ms.finish({ page, pages: count }, 0)} className="flex min-h-tap-kids-xl items-center rounded-xl bg-kids-me-fill px-s5 font-display text-kids-label shadow-kid-raised">The end</button>
        ) : (
          <button onClick={() => go(1)} aria-label="Next page" className="flex size-tap-kids-xl items-center justify-center rounded-pill bg-kids-surface shadow-kid-raised"><NextIcon className="size-icon-kids" /></button>
        )}
      </div>
      {restored !== null && page === restored && (
        <p className="text-kids-body">You were on page {restored + 1}. <button className="font-bold underline" onClick={() => { setRestored(null); setPage(0); }}>Start from the beginning</button></p>
      )}
      {ms.reward && <Celebration stars={ms.reward.stars} next={p.done} />}
      {ms.locked && <TimeUp back="/kids/games" />}
    </div>
  );
}
