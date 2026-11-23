"use client";
// The game and quiz player. The engine (lib/engine, a port of the app's) builds the items, judges
// answers, gives hints and keeps score; this component shows it and reports the session:
// "started" when play begins, then "completed" or "abandoned" (leaving mid-game), to /play/sync.
import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  currentItem, endedReport, isLast, promptSpoken, runSummary, standardRegistry, startedReport, startRun, textOf,
  type ActivitySource, type Hint, type ItemAnswer, type RunState, type SessionEngine,
} from "@/lib/engine";
import { sendItem } from "@/lib/play-client";
import { CheckIcon, HintIcon, PlayIcon, SpeakerIcon, StarIcon } from "../icons";
import { PictureView } from "./picture";
import { setMuted, speak } from "./speech";
import { ChoiceView, MemoryView, OrderView, PlaceView, TraceView } from "./views";

type Props = { source: ActivitySource; childId: string; ageMonths: number; stepId: string | null; title: string; back: { href: string; label: string } };
const NO_HINT: Hint = { text: {}, eliminate: [], reveal: [] };
const PRAISE = ["Great job!", "Brilliant!", "You did it!", "Super!", "Well done!"];

export function Player(p: Props) {
  const registry = useMemo(() => standardRegistry(), []);
  const [run, setRun] = useState<{ engine: SessionEngine; state: RunState; source: ActivitySource } | { error: string } | null>(null);
  const [hint, setHint] = useState<Hint>(NO_HINT);
  const [sound, setSound] = useState(true);
  const [stars, setStars] = useState<number | null>(null);
  const reported = useRef<"none" | "started" | "ended">("none");
  const ctx = useMemo(() => ({ source: (p.stepId ? "course" : "feed") as "course" | "feed", platform: "web" as const, appVersion: "web-1", contentVersion: p.source.contentVersion }), [p.stepId, p.source.contentVersion]);

  const create = useCallback((runNo = 1) => {
    try {
      const r = startRun({ source: p.source, registry, sessionId: crypto.randomUUID(), childId: p.childId, ageMonths: p.ageMonths, lessonStepId: p.stepId, run: runNo, now: Date.now() });
      reported.current = "none";
      setStars(null); setHint(NO_HINT);
      setRun({ engine: r.engine, state: r.state, source: r.source });
    } catch (e) {
      setRun({ error: e instanceof Error ? e.message : "This game can't be played right now." });
    }
  }, [p.source, registry, p.childId, p.ageMonths, p.stepId]);
  useEffect(() => create(), [create]);
  useEffect(() => setMuted(!sound), [sound]);

  const state = run && "state" in run ? run.state : null;
  // Leaving mid-game (closing the tab, or navigating away): report it as abandoned, once.
  // Refs, so this fires on unmount / pagehide only — never because the state changed.
  const latest = useRef<{ state: RunState | null; ctx: typeof ctx }>({ state: null, ctx });
  latest.current = { state, ctx };
  useEffect(() => {
    const leave = () => {
      const { state: st, ctx: c } = latest.current;
      if (st && reported.current === "started") { reported.current = "ended"; void sendItem(endedReport(st, Date.now(), c)); }
    };
    window.addEventListener("pagehide", leave);
    return () => { window.removeEventListener("pagehide", leave); leave(); };
  }, []);
  // Say each new question out loud when the level asks for it.
  useEffect(() => { if (state?.phase === "question" && run && "engine" in run && run.engine.policy.autoSpeak) speak(promptSpoken(currentItem(state).prompt)); }, [state?.phase, state?.index]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!run) return <p className="text-kids-body">Getting the game ready…</p>;
  if ("error" in run) return <div role="alert" className="rounded-xl bg-kids-bg-alt p-s6 text-kids-body">Sorry, this one isn&apos;t working right now. <Link href={p.back.href} className="font-bold underline">{p.back.label}</Link></div>;
  const { engine, state: s } = run;
  const set = (next: RunState) => setRun({ ...run, state: next });

  const begin = () => {
    const next = engine.begin(s, Date.now());
    set(next);
    if (reported.current === "none") { reported.current = "started"; void sendItem(startedReport(next, ctx)); }
  };
  const answer = (a: ItemAnswer) => {
    const { state: next } = engine.answer(s, a, Date.now());
    set(next); setHint(NO_HINT);
    speak(next.feedback === "correct" ? PRAISE[next.index % PRAISE.length] : next.feedback === "tryAgain" ? "Nearly! Try again." : "Here's the answer.");
  };
  const go = async () => {
    const next = engine.next(s, Date.now());
    set(next);
    if (next.phase === "completed" && reported.current === "started") {
      reported.current = "ended";
      const r = await sendItem(endedReport(next, Date.now(), ctx));
      setStars(Number(r?.rewards?.stars ?? 0));
    }
  };
  const askHint = () => { const r = engine.hint(s); set(r.state); setHint(r.hint); const t = textOf(r.hint.text); if (t) speak(t); };

  const total = s.items.length;
  return (
    <div className="flex flex-col gap-s5">
      <div className="flex flex-wrap items-center justify-between gap-s3">
        <h1 className="font-display text-kids-title">{p.title}</h1>
        <div className="flex items-center gap-s2">
          <button type="button" onClick={() => setSound((x) => !x)} aria-pressed={sound} className="flex min-h-tap-kids-secondary items-center gap-s2 rounded-lg bg-kids-surface px-s4 font-bold shadow-kid-raised"><SpeakerIcon />{sound ? "Sound on" : "Sound off"}</button>
          <Link href={p.back.href} className="flex min-h-tap-kids-secondary items-center rounded-lg px-s4 font-bold underline">Stop</Link>
        </div>
      </div>
      {s.phase !== "intro" && s.phase !== "completed" && (
        <ol className="flex gap-s1" aria-label={`Question ${s.index + 1} of ${total}`}>
          {s.items.map((it, i) => <li key={it.id} className={`h-s2 flex-1 rounded-pill ${i < s.index || (i === s.index && s.phase === "feedback") ? "bg-kids-success-fill" : i === s.index ? "bg-kids-learn-fill" : "bg-kids-line"}`} />)}
        </ol>
      )}

      {s.phase === "intro" && (
        <div className="flex flex-col items-center gap-s6 rounded-xl bg-kids-surface p-s8 text-center shadow-kid-raised">
          {run.source.intro.picture && <span className="size-kids-art-lg"><PictureView picture={run.source.intro.picture} /></span>}
          <p className="max-w-ui-form-w text-kids-body">{textOf(run.source.intro.text) || `${total} ${total === 1 ? "thing" : "things"} to do. Ready?`}</p>
          <button type="button" autoFocus onClick={begin} className="flex min-h-tap-kids-xl items-center gap-s3 rounded-xl bg-kids-play-fill px-s8 font-display text-kids-title shadow-kid-raised"><PlayIcon className="size-icon-kids" />Play</button>
        </div>
      )}

      {(s.phase === "question" || s.phase === "feedback") && (() => {
        const item = currentItem(s);
        const disabled = s.phase !== "question";
        const v = { hint, disabled, onAnswer: answer };
        return (
          <div className="flex flex-col gap-s5">
            <div className="flex flex-col items-center gap-s3 text-center">
              {item.prompt.picture && item.kind !== "word_build" && <span className="size-kids-node"><PictureView picture={item.prompt.picture} label /></span>}
              <p className="font-display text-kids-heading">{textOf(item.prompt.text)}</p>
              <button type="button" onClick={() => speak(promptSpoken(item.prompt))} className="flex min-h-tap-kids-secondary items-center gap-s2 rounded-pill bg-kids-listen-soft px-s4 font-bold"><SpeakerIcon />Listen</button>
            </div>
            {"options" in item ? <ChoiceView spec={item} {...v} />
              : item.kind === "memory" ? <MemoryView spec={item} {...v} />
              : item.kind === "trace" ? <TraceView spec={item} {...v} />
              : "order" in item ? <OrderView spec={item} {...v} />
              : <PlaceView spec={item} {...v} />}
            {s.phase === "question" && (
              <div className="flex flex-col items-center gap-s2">
                <button type="button" onClick={askHint} className="flex min-h-tap-kids-secondary items-center gap-s2 rounded-lg bg-kids-surface px-s4 font-bold shadow-kid-raised"><HintIcon />Help me</button>
                {textOf(hint.text) && <p role="status" className="text-kids-body">{textOf(hint.text)}</p>}
              </div>
            )}
            {s.phase === "feedback" && (
              <div role="status" className={`pop flex flex-col items-center gap-s4 rounded-xl p-s6 text-center ${s.feedback === "correct" ? "bg-kids-me-soft" : s.feedback === "tryAgain" ? "bg-kids-play-soft" : "bg-kids-learn-soft"}`}>
                <p className="flex items-center gap-s2 font-display text-kids-title">{s.feedback === "correct" ? <><CheckIcon className="size-icon-kids" />{PRAISE[s.index % PRAISE.length]}</> : s.feedback === "tryAgain" ? "Nearly! Have another go." : "That's OK — this is the answer."}</p>
                {s.feedback === "tryAgain"
                  ? <button type="button" autoFocus onClick={() => set(engine.retry(s, Date.now()))} className="min-h-tap-kids rounded-xl bg-kids-play-fill px-s8 font-display text-kids-label shadow-kid-raised">Try again</button>
                  : <button type="button" autoFocus onClick={() => void go()} className="min-h-tap-kids rounded-xl bg-kids-me-fill px-s8 font-display text-kids-label shadow-kid-raised">{isLast(s) ? "Finish" : "Next"}</button>}
              </div>
            )}
          </div>
        );
      })()}

      {s.phase === "completed" && (() => {
        const sum = runSummary(s);
        return (
          <div className="celebrate flex flex-col items-center gap-s5 rounded-xl bg-kids-surface p-s8 text-center shadow-kid-raised" role="status">
            <span className="text-kids-star"><StarIcon className="size-kids-node" /></span>
            <h2 className="font-display text-kids-title">All done!</h2>
            <ul className="text-kids-body">{sum.lines.map((l) => <li key={l}>{l}</li>)}</ul>
            <p className="text-kids-body" aria-live="polite">{stars === null ? "Saving…" : stars > 0 ? `You earned ${stars} ${stars === 1 ? "star" : "stars"}!` : "Saved. (Today's star for this one is already yours.)"}</p>
            <div className="flex flex-wrap justify-center gap-s3">
              <button type="button" onClick={() => create(s.run + 1)} className="min-h-tap-kids rounded-xl bg-kids-play-fill px-s6 font-display text-kids-label shadow-kid-raised">Play again</button>
              <Link href={p.back.href} className="inline-flex min-h-tap-kids items-center rounded-xl bg-kids-me-fill px-s6 font-display text-kids-label shadow-kid-raised">{p.back.label}</Link>
            </div>
          </div>
        );
      })()}
    </div>
  );
}
