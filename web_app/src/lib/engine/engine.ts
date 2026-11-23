/**
 * The rules of a run (port of engine.dart and run_summary.dart). Pure: every function takes a
 * state and returns the next one, so the player UI, the tests and resuming share one
 * implementation. Phases: intro → question → feedback → … → completed.
 *
 * Deviations from Dart:
 * - Times are epoch milliseconds (`now: number`), not DateTime.
 * - `startRun` is new: it bundles what the Flutter PlayerController does to start a run
 *   (default level by age, policy by age + difficulty + level, build items, create).
 * - `again` keeps Dart's behaviour of not carrying the level over (the Flutter player calls
 *   `create` with the level instead; `startRun` does the same).
 * - `restore` returns null for a malformed snapshot (Dart's casts would throw).
 */
import { policyForChild, textIsEmpty, textOf } from "./common";
import type { KindRegistry } from "./registry";
import type { ActivitySource } from "./source";
import { applyLevel, buildItems, currentLevel, defaultLevel, forLevel } from "./source";
import type { DifficultyPolicy, Hint, ItemAnswer, ItemSpec, Json, Verdict } from "./types";
import { answerToJson, ContentError, noHint, wrong } from "./types";

export type PlayPhase = "intro" | "question" | "feedback" | "completed";
export type FeedbackKind = "correct" | "tryAgain" | "revealed";

/** What happened to one item. */
export interface ItemProgress {
  /** Wrong answers submitted. */
  readonly wrongAttempts: number;
  /** Wrong sub-moves inside the final answer (bounced drops, extra memory flips). */
  readonly mistakes: number;
  readonly hintLevel: number;
  readonly correct: boolean;
  /** Shown the answer after the last try. */
  readonly revealed: boolean;
  /** Every answer given, compact (answerToJson), in order. */
  readonly answers: readonly Json[];
  readonly spentMs: number;
}

export const emptyProgress: ItemProgress = Object.freeze({
  wrongAttempts: 0,
  mistakes: 0,
  hintLevel: 0,
  correct: false,
  revealed: false,
  answers: [],
  spentMs: 0,
});

export const isDone = (p: ItemProgress) => p.correct || p.revealed;
export const attemptsOf = (p: ItemProgress) => p.wrongAttempts + (p.correct ? 1 : 0);

/** 0..1: full marks first time; less for retries, mistakes and hints; 0 when not right. */
export function pointsOf(p: ItemProgress): number {
  if (!p.correct) return 0;
  const v = 1 - 0.25 * p.wrongAttempts - 0.1 * p.mistakes - 0.1 * p.hintLevel;
  return v < 0.25 ? 0.25 : v > 1 ? 1 : v;
}

/** One run of one activity by one child. Immutable. */
export interface RunState {
  readonly sessionId: string;
  readonly childId: string;
  readonly activityId: string;
  readonly lessonStepId: string | null;
  readonly items: readonly ItemSpec[];
  readonly progress: readonly ItemProgress[];
  readonly phase: PlayPhase;
  readonly index: number;
  readonly feedback: FeedbackKind | null;
  readonly startedAt: number;
  readonly endedAt: number | null;
  /** Time actually playing (pauses and the intro don't count), up to resumedAt. */
  readonly activeMs: number;
  /** When the current playing stretch began (null while paused or not started). */
  readonly resumedAt: number | null;
  /** When the current item appeared (for per-item time). */
  readonly itemShownAt: number | null;
  /** 1 for the first play in a row, 2 after "Play again", … */
  readonly run: number;
  /** The game level being played (null for games without levels). */
  readonly level: string | null;
}

export const currentItem = (s: RunState): ItemSpec => s.items[s.index];
export const currentProgress = (s: RunState): ItemProgress => s.progress[s.index];
export const isLast = (s: RunState) => s.index === s.items.length - 1;
export const correctCount = (s: RunState) => s.progress.filter((p) => p.correct).length;
/** Wrong answers plus wrong sub-moves, over every item. */
export const incorrectCount = (s: RunState) => s.progress.reduce((n, p) => n + p.wrongAttempts + p.mistakes, 0);
export const hintsUsed = (s: RunState) => s.progress.reduce((n, p) => n + p.hintLevel, 0);

/** 0..100. */
export function scoreOf(s: RunState): number {
  if (s.items.length === 0) return 0;
  return Math.round((100 * s.progress.reduce((n, p) => n + pointsOf(p), 0)) / s.items.length);
}

/** 1–3 celebration stars on the completion screen. */
export const celebrationStars = (s: RunState) => {
  const sc = scoreOf(s);
  return sc >= 85 ? 3 : sc >= 60 ? 2 : 1;
};

export function activeMsAt(s: RunState, now: number): number {
  return s.activeMs + (s.resumedAt === null ? 0 : Math.max(0, now - s.resumedAt));
}

/** Saved on the device so an interrupted run can continue (item content is re-parsed). */
export interface RunSnapshot {
  v: 1;
  sessionId: string;
  childId: string;
  activityId: string;
  lessonStepId: string | null;
  itemIds: string[];
  index: number;
  phase: "completed" | "question";
  progress: { w: number; m: number; h: number; c: boolean; r: boolean; a: Json[]; t: number }[];
  startedAt: string;
  activeMs: number;
  run: number;
  level?: string;
  savedAt: string;
}

const iso = (ms: number) => new Date(ms).toISOString();

export function toSnapshot(s: RunState, now: number): RunSnapshot {
  const snap: RunSnapshot = {
    v: 1,
    sessionId: s.sessionId,
    childId: s.childId,
    activityId: s.activityId,
    lessonStepId: s.lessonStepId,
    itemIds: s.items.map((i) => i.id),
    index: s.index,
    phase: s.phase === "completed" ? "completed" : "question",
    progress: s.progress.map((p) => ({
      w: p.wrongAttempts,
      m: p.mistakes,
      h: p.hintLevel,
      c: p.correct,
      r: p.revealed,
      a: [...p.answers],
      t: p.spentMs,
    })),
    startedAt: iso(s.startedAt),
    activeMs: activeMsAt(s, now),
    run: s.run,
    savedAt: iso(now),
  };
  if (s.level !== null) snap.level = s.level;
  return snap;
}

const num = (v: unknown, d: number) => (typeof v === "number" ? Math.trunc(v) : d);

export interface CreateOptions {
  sessionId: string;
  childId: string;
  activityId: string;
  items: readonly ItemSpec[];
  now: number;
  lessonStepId?: string | null;
  run?: number;
  level?: string | null;
}

export class SessionEngine {
  constructor(
    readonly registry: KindRegistry,
    readonly policy: DifficultyPolicy,
  ) {}

  create(o: CreateOptions): RunState {
    if (o.items.length === 0) throw new ContentError("an activity needs at least one item");
    return {
      sessionId: o.sessionId,
      childId: o.childId,
      activityId: o.activityId,
      lessonStepId: o.lessonStepId ?? null,
      items: o.items,
      progress: o.items.map(() => emptyProgress),
      phase: "intro",
      index: 0,
      feedback: null,
      startedAt: o.now,
      endedAt: null,
      activeMs: 0,
      resumedAt: null,
      itemShownAt: null,
      run: o.run ?? 1,
      level: o.level ?? null,
    };
  }

  /** Rebuilds a saved run; null when the content changed since (different items). */
  restore(snap: unknown, items: readonly ItemSpec[]): RunState | null {
    if (typeof snap !== "object" || snap === null) return null;
    const j = snap as Record<string, unknown>;
    const ids = j.itemIds;
    if (j.v !== 1 || !Array.isArray(ids) || ids.length !== items.length) return null;
    for (let i = 0; i < ids.length; i++) if (ids[i] !== items[i].id) return null;
    if (!Array.isArray(j.progress) || j.progress.length !== items.length) return null;
    const progress: ItemProgress[] = j.progress.map((x) => {
      const p = (typeof x === "object" && x !== null ? x : {}) as Record<string, unknown>;
      return {
        wrongAttempts: num(p.w, 0),
        mistakes: num(p.m, 0),
        hintLevel: num(p.h, 0),
        correct: p.c === true,
        revealed: p.r === true,
        answers: Array.isArray(p.a) ? (p.a as Json[]) : [],
        spentMs: num(p.t, 0),
      };
    });
    let index = Math.min(Math.max(num(j.index, 0), 0), items.length - 1);
    // An item finished just before the interruption: continue with the next one.
    while (isDone(progress[index]) && index < items.length - 1) index++;
    const startedAt = Date.parse(String(j.startedAt));
    if (typeof j.sessionId !== "string" || typeof j.childId !== "string" || typeof j.activityId !== "string" || Number.isNaN(startedAt)) {
      return null;
    }
    return {
      sessionId: j.sessionId,
      childId: j.childId,
      activityId: j.activityId,
      lessonStepId: typeof j.lessonStepId === "string" ? j.lessonStepId : null,
      items,
      progress,
      phase: progress.every(isDone) ? "completed" : "question",
      index,
      feedback: null,
      startedAt,
      endedAt: null,
      activeMs: num(j.activeMs, 0),
      resumedAt: null,
      itemShownAt: null,
      run: num(j.run, 1),
      level: typeof j.level === "string" ? j.level : null,
    };
  }

  /** Intro → first item, or back into play after a resume. */
  begin(s: RunState, now: number): RunState {
    if (s.phase === "completed") return s;
    return {
      ...s,
      phase: s.phase === "intro" ? "question" : s.phase,
      resumedAt: s.resumedAt ?? now,
      itemShownAt: now,
    };
  }

  /** Stops the clock (pause sheet, tab hidden). */
  pause(s: RunState, now: number): RunState {
    return s.resumedAt === null ? s : { ...s, activeMs: activeMsAt(s, now), resumedAt: null };
  }

  resume(s: RunState, now: number): RunState {
    return s.resumedAt !== null || s.phase === "completed" || s.phase === "intro" ? s : { ...s, resumedAt: now };
  }

  /** Right → "correct". Wrong with tries left → "tryAgain". Wrong on the last try → "revealed". */
  answer(s: RunState, a: ItemAnswer, now: number): { state: RunState; verdict: Verdict } {
    if (s.phase !== "question" || isDone(currentProgress(s))) return { state: s, verdict: wrong() };
    const e = this.registry.evaluate(currentItem(s), a);
    const p = currentProgress(s);
    const spent = p.spentMs + (s.itemShownAt === null ? 0 : Math.max(0, now - s.itemShownAt));
    const log = [...p.answers, answerToJson(a)];
    let next: ItemProgress;
    let fb: FeedbackKind;
    if (e.correct) {
      next = { ...p, correct: true, mistakes: e.mistakes, answers: log, spentMs: spent };
      fb = "correct";
    } else if (p.wrongAttempts + 1 >= this.policy.maxAttempts) {
      next = { ...p, wrongAttempts: p.wrongAttempts + 1, revealed: true, answers: log, spentMs: spent };
      fb = "revealed";
    } else {
      next = { ...p, wrongAttempts: p.wrongAttempts + 1, answers: log, spentMs: spent };
      fb = "tryAgain";
    }
    const progress = [...s.progress];
    progress[s.index] = next;
    return { state: { ...s, progress, phase: "feedback", feedback: fb, itemShownAt: now }, verdict: e };
  }

  /** "Try again" after a wrong answer: back to the same item. */
  retry(s: RunState, now: number): RunState {
    if (s.phase !== "feedback" || s.feedback !== "tryAgain") return s;
    return { ...s, phase: "question", feedback: null, itemShownAt: now };
  }

  /** The next hint. When the type has nothing more, the last hint repeats and the level doesn't
   * rise (so the score isn't lowered for nothing). */
  hint(s: RunState): { state: RunState; hint: Hint } {
    if (s.phase !== "question") return { state: s, hint: noHint };
    const cur = currentProgress(s);
    const level = cur.hintLevel + 1;
    const h = this.registry.hint(currentItem(s), level);
    const empty = textIsEmpty(h.text) && h.eliminate.length === 0 && h.reveal.length === 0;
    const previous = this.registry.hint(currentItem(s), cur.hintLevel);
    const same =
      h.eliminate.length === previous.eliminate.length &&
      h.reveal.length === previous.reveal.length &&
      textOf(h.text) === textOf(previous.text) &&
      cur.hintLevel > 0;
    if (empty || same) return { state: s, hint: previous };
    const progress = [...s.progress];
    progress[s.index] = { ...cur, hintLevel: level };
    return { state: { ...s, progress }, hint: h };
  }

  /** The answer to show after "revealed" (null for memory and trace). */
  solution(s: RunState): ItemAnswer | null {
    return this.registry.solution(currentItem(s));
  }

  /** After "correct" or "revealed": the next item, or the end. */
  next(s: RunState, now: number): RunState {
    if (s.phase !== "feedback" || s.feedback === "tryAgain") return s;
    if (isLast(s)) {
      return { ...s, phase: "completed", feedback: null, activeMs: activeMsAt(s, now), resumedAt: null, endedAt: now };
    }
    return { ...s, index: s.index + 1, phase: "question", feedback: null, itemShownAt: now };
  }

  /** "Play again": a new session over the same items, everything reset (level not kept, as Dart). */
  again(s: RunState, o: { sessionId: string; now: number }): RunState {
    return {
      sessionId: o.sessionId,
      childId: s.childId,
      activityId: s.activityId,
      lessonStepId: s.lessonStepId,
      items: s.items,
      progress: s.items.map(() => emptyProgress),
      phase: "question",
      index: 0,
      feedback: null,
      startedAt: o.now,
      endedAt: null,
      activeMs: 0,
      resumedAt: o.now,
      itemShownAt: o.now,
      run: s.run + 1,
      level: null,
    };
  }
}

// --- Starting a run (what the Flutter PlayerController does) -------------------------------

/** The child's settings, adjusted by the level being played. */
export function policyFor(source: ActivitySource, ageMonths: number): DifficultyPolicy {
  return applyLevel(currentLevel(source), policyForChild(ageMonths, source.difficulty));
}

export interface StartRunOptions {
  /** Content with all levels (`fromConfig` / `sourceFromRow`). */
  source: ActivitySource;
  registry: KindRegistry;
  sessionId: string;
  childId: string;
  /** Child's age; the Flutter app uses 48 when unknown. */
  ageMonths?: number | null;
  /** Level to play; default: the hardest one the child is old enough for. */
  levelId?: string | null;
  lessonStepId?: string | null;
  run?: number;
  now: number;
}

export interface StartedRun {
  engine: SessionEngine;
  /** The level being played (its rawItems), for nextLevel / contentVersion. */
  source: ActivitySource;
  policy: DifficultyPolicy;
  /** In the intro phase: call `engine.begin(state, now)` when the child taps Play. */
  state: RunState;
}

/** Picks the level, the policy and builds the items; throws ContentError for broken content. */
export function startRun(o: StartRunOptions): StartedRun {
  const age = o.ageMonths ?? 48;
  const src = forLevel(o.source, o.levelId ?? defaultLevel(o.source, age)?.id ?? null);
  const policy = policyFor(src, age);
  const engine = new SessionEngine(o.registry, policy);
  const state = engine.create({
    sessionId: o.sessionId,
    childId: o.childId,
    activityId: o.source.activityId,
    lessonStepId: o.lessonStepId,
    items: buildItems(src, o.registry, policy, o.sessionId),
    now: o.now,
    run: o.run,
    level: src.levelId,
  });
  return { engine, source: src, policy, state };
}

// --- Completion summary (run_summary.dart) ------------------------------------------------

export interface RunSummary {
  /** Right first time or after a retry (not the answers shown). */
  correct: number;
  total: number;
  /** Memory: pairs of cards turned, including misses. */
  moves: number | null;
  timeMs: number | null;
  /** Short lines: "8 of 10 right", "14 moves", "Time 0:42". */
  lines: string[];
}

export function clock(ms: number): string {
  const s = Math.floor(ms / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

export function runSummary(run: RunState): RunSummary {
  let moves: number | null = null;
  let timeMs: number | null = null;
  run.items.forEach((item, i) => {
    if (item.kind !== "memory") return;
    for (const a of run.progress[i].answers) {
      if (typeof a !== "object" || a === null || Array.isArray(a)) continue;
      moves = (moves ?? 0) + (typeof a.f === "number" ? Math.trunc(a.f) : 0);
      if (typeof a.ms === "number") timeMs = (timeMs ?? 0) + Math.trunc(a.ms);
    }
  });
  const correct = correctCount(run);
  const total = run.items.length;
  const lines: string[] = [];
  if (total > 1) lines.push(`${correct} of ${total} right`);
  if (moves !== null) lines.push(`${moves} moves`);
  if (timeMs !== null) lines.push(`Time ${clock(timeMs)}`);
  return { correct, total, moves, timeMs, lines };
}
