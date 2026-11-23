"use client";
import { useEffect, useRef, useState } from "react";
import { clock } from "@/lib/format";
import type { LaunchFile } from "@/lib/data/launch";
import { worthResuming, type Resume } from "@/lib/rules";
import { PauseIcon, PlayIcon } from "../icons";
import { Celebration, TimeUp } from "./overlays";
import { localResume, newer, useMediaSession } from "./use-media-session";

type Props = { childId: string; activityId: string; title: string; contentVersion: number; stepId?: string | null; files: LaunchFile[]; resume: Resume | null; poster: string | null; done: { href: string; label: string } };

export function VideoPlayer(p: Props) {
  const video = useRef<HTMLVideoElement>(null);
  const mp4 = p.files.find((f) => f.role === "video_main");
  const subs = p.files.filter((f) => f.role === "subtitle");
  const ms = useMediaSession({ childId: p.childId, activityId: p.activityId, contentVersion: p.contentVersion, stepId: p.stepId, section: "watch" });
  const [playing, setPlaying] = useState(false);
  const [t, setT] = useState(0);
  const [dur, setDur] = useState((mp4?.durationMs ?? 0) / 1000);
  const [captions, setCaptions] = useState(true);
  const [from, setFrom] = useState<Resume | null>(null);
  const started = useRef(false);

  useEffect(() => { const r = newer(p.resume, localResume(p.childId, p.activityId)); if (worthResuming(r)) setFrom(r); }, [p.resume, p.childId, p.activityId]);
  useEffect(() => { const v = video.current; if (v) for (const tr of Array.from(v.textTracks)) tr.mode = captions ? "showing" : "hidden"; }, [captions]);
  useEffect(() => {
    if (!playing) return;
    const id = setInterval(() => { ms.tick(); const v = video.current; if (v && Math.floor(v.currentTime) % 5 === 0) ms.save({ positionMs: Math.round(v.currentTime * 1000), durationMs: Math.round(v.duration * 1000) }); }, 1000);
    return () => clearInterval(id);
  }, [playing, ms]);
  useEffect(() => { if (ms.locked) video.current?.pause(); }, [ms.locked]);

  if (!mp4) return <p className="text-kids-body">This video isn&apos;t ready yet.</p>;
  const toggle = () => { const v = video.current!; if (v.paused) void v.play(); else v.pause(); };
  return (
    <div className="flex flex-col gap-s4">
      <div className="relative overflow-hidden rounded-xl bg-kids-scrim">
        <video ref={video} className="aspect-video w-full" src={mp4.url} poster={p.poster ?? undefined} preload="metadata" playsInline crossOrigin="anonymous"
          onLoadedMetadata={(e) => { setDur(e.currentTarget.duration); if (from?.positionMs && !started.current) e.currentTarget.currentTime = from.positionMs / 1000; }}
          onPlay={() => { setPlaying(true); if (!started.current) { started.current = true; ms.start(); } }}
          onPause={(e) => { setPlaying(false); ms.save({ positionMs: Math.round(e.currentTarget.currentTime * 1000), durationMs: Math.round(e.currentTarget.duration * 1000) }); }}
          onTimeUpdate={(e) => { const v = e.currentTarget; setT(v.currentTime); if (v.duration && v.currentTime / v.duration >= 0.95) void ms.finish({ positionMs: Math.round(v.duration * 1000), durationMs: Math.round(v.duration * 1000) }, Math.round(v.duration * 1000)); }}
          onEnded={(e) => void ms.finish({ positionMs: Math.round(e.currentTarget.duration * 1000), durationMs: Math.round(e.currentTarget.duration * 1000) }, Math.round(e.currentTarget.duration * 1000))}
          onClick={toggle} aria-label={p.title}>
          {subs.map((s) => <track key={s.url} kind="captions" src={s.url} srcLang={s.locale ?? "en"} label={s.locale === "en" || !s.locale ? "English" : s.locale} default />)}
        </video>
        {!playing && (
          <button onClick={toggle} className="absolute inset-0 m-auto flex size-kids-node items-center justify-center rounded-pill bg-kids-surface/90 text-kids-ink shadow-kid-raised" aria-label="Play">
            <PlayIcon className="size-icon-kids" />
          </button>
        )}
      </div>
      {from && !started.current && (
        <p className="flex flex-wrap items-center gap-s3 text-kids-body">Carrying on from {clock(from.positionMs ?? 0)}.
          <button className="min-h-tap-kids-secondary rounded-lg bg-kids-surface px-s4 font-bold shadow-kid-raised" onClick={() => { setFrom(null); if (video.current) video.current.currentTime = 0; }}>Start again</button>
        </p>
      )}
      <div className="flex flex-wrap items-center gap-s4">
        <button onClick={toggle} className="flex size-tap-kids items-center justify-center rounded-pill bg-kids-watch-fill shadow-kid-raised" aria-label={playing ? "Pause" : "Play"}>
          {playing ? <PauseIcon className="size-icon-kids" /> : <PlayIcon className="size-icon-kids" />}
        </button>
        <input type="range" min={0} max={Math.max(1, Math.floor(dur))} value={Math.floor(t)} aria-label="Position" aria-valuetext={`${clock(t * 1000)} of ${clock(dur * 1000)}`}
          onChange={(e) => { if (video.current) video.current.currentTime = Number(e.target.value); }} className="min-w-0 flex-1 accent-kids-watch-fill" />
        <span className="tabular-nums text-kids-caption">{clock(t * 1000)} / {clock(dur * 1000)}</span>
        {subs.length > 0 && (
          <button onClick={() => setCaptions((c) => !c)} aria-pressed={captions} className="min-h-tap-kids-secondary rounded-lg bg-kids-surface px-s4 font-bold shadow-kid-raised">Captions {captions ? "on" : "off"}</button>
        )}
      </div>
      {ms.reward && <Celebration stars={ms.reward.stars} next={p.done} />}
      {ms.locked && <TimeUp back="/kids/games" />}
    </div>
  );
}
