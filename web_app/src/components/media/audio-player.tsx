"use client";
/* eslint-disable @next/next/no-img-element -- cover art from the public bucket */
import { useEffect, useRef, useState } from "react";
import { clock } from "@/lib/format";
import type { LaunchFile } from "@/lib/data/launch";
import { worthResuming, type Resume } from "@/lib/rules";
import { PauseIcon, PlayIcon } from "../icons";
import { Celebration, TimeUp } from "./overlays";
import { localResume, newer, useMediaSession } from "./use-media-session";

type Props = { childId: string; activityId: string; title: string; contentVersion: number; stepId?: string | null; files: LaunchFile[]; resume: Resume | null; cover: string | null; done: { href: string; label: string } };

/** Songs and audio stories: a big cover, one big play button, a position slider. */
export function AudioPlayer(p: Props) {
  const audio = useRef<HTMLAudioElement>(null);
  const main = p.files.find((f) => f.role === "audio_main");
  const ms = useMediaSession({ childId: p.childId, activityId: p.activityId, contentVersion: p.contentVersion, stepId: p.stepId, section: "listen" });
  const [playing, setPlaying] = useState(false);
  const [t, setT] = useState(0);
  const [dur, setDur] = useState((main?.durationMs ?? 0) / 1000);
  const [from, setFrom] = useState<Resume | null>(null);
  const started = useRef(false);

  useEffect(() => { const r = newer(p.resume, localResume(p.childId, p.activityId)); if (worthResuming(r)) setFrom(r); }, [p.resume, p.childId, p.activityId]);
  useEffect(() => {
    if (!playing) return;
    const id = setInterval(() => { ms.tick(); const a = audio.current; if (a && Math.floor(a.currentTime) % 5 === 0) ms.save({ positionMs: Math.round(a.currentTime * 1000), durationMs: Math.round(a.duration * 1000) }); }, 1000);
    return () => clearInterval(id);
  }, [playing, ms]);
  useEffect(() => { if (ms.locked) audio.current?.pause(); }, [ms.locked]);

  if (!main) return <p className="text-kids-body">This one isn&apos;t ready yet.</p>;
  const toggle = () => { const a = audio.current!; if (a.paused) void a.play(); else a.pause(); };
  const end = (a: HTMLAudioElement) => void ms.finish({ positionMs: Math.round(a.duration * 1000), durationMs: Math.round(a.duration * 1000) }, Math.round(a.duration * 1000));
  return (
    <div className="flex flex-col items-center gap-s5 md:flex-row md:items-start md:gap-s8">
      <div className="size-kids-art-lg shrink-0 overflow-hidden rounded-xl bg-kids-listen-soft shadow-kid-raised md:size-kids-hero-h">
        {p.cover && <img src={p.cover} alt="" className={`size-full object-cover ${playing ? "pop" : ""}`} />}
      </div>
      <div className="flex w-full flex-col gap-s4">
        <audio ref={audio} src={main.url} preload="metadata"
          onLoadedMetadata={(e) => { setDur(e.currentTarget.duration); if (from?.positionMs && !started.current) e.currentTarget.currentTime = from.positionMs / 1000; }}
          onPlay={() => { setPlaying(true); if (!started.current) { started.current = true; ms.start(); } }}
          onPause={(e) => { setPlaying(false); ms.save({ positionMs: Math.round(e.currentTarget.currentTime * 1000), durationMs: Math.round(e.currentTarget.duration * 1000) }); }}
          onTimeUpdate={(e) => { const a = e.currentTarget; setT(a.currentTime); if (a.duration && a.currentTime / a.duration >= 0.95) end(a); }}
          onEnded={(e) => end(e.currentTarget)} />
        <button onClick={toggle} className="flex size-kids-node items-center justify-center self-center rounded-pill bg-kids-listen-fill shadow-kid-raised md:self-start" aria-label={playing ? "Pause" : "Play"}>
          {playing ? <PauseIcon className="size-icon-kids" /> : <PlayIcon className="size-icon-kids" />}
        </button>
        <div className="flex items-center gap-s3">
          <input type="range" min={0} max={Math.max(1, Math.floor(dur))} value={Math.floor(t)} aria-label="Position" aria-valuetext={`${clock(t * 1000)} of ${clock(dur * 1000)}`}
            onChange={(e) => { if (audio.current) audio.current.currentTime = Number(e.target.value); }} className="min-w-0 flex-1 accent-kids-listen-fill" />
          <span className="tabular-nums text-kids-caption">{clock(t * 1000)} / {clock(dur * 1000)}</span>
        </div>
        {from && !started.current && (
          <p className="flex flex-wrap items-center gap-s3 text-kids-body">Carrying on from {clock(from.positionMs ?? 0)}.
            <button className="min-h-tap-kids-secondary rounded-lg bg-kids-surface px-s4 font-bold shadow-kid-raised" onClick={() => { setFrom(null); if (audio.current) audio.current.currentTime = 0; }}>Start again</button>
          </p>
        )}
      </div>
      {ms.reward && <Celebration stars={ms.reward.stars} next={p.done} />}
      {ms.locked && <TimeUp back="/kids/games" />}
    </div>
  );
}
