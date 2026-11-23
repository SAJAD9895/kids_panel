/**
 * What the app uploads for one session: a `POST /play/sync` item (port of SessionReport in
 * session_report.dart), built from a RunState exactly like the Flutter app so progress syncs
 * the same way. Optional keys are left out (not sent as null) like Dart's `'k': ?v`.
 */
import type { RunState } from "./engine";
import { activeMsAt, correctCount, hintsUsed, incorrectCount, isDone, scoreOf } from "./engine";
import { dartStr } from "./common";
import type { ItemSpec, Json } from "./types";

export type SessionStatus = "started" | "completed" | "abandoned";
export type PlaySource =
  | "feed"
  | "search"
  | "collection"
  | "course"
  | "favorite"
  | "shuffle"
  | "together"
  | "learning_path"
  | "offline";
export type Platform = "ios" | "android" | "web";

/** Per item: kind, right, wrong tries, mistakes, hints, revealed, time. */
export interface ItemMetric {
  k: string;
  ok: boolean;
  w: number;
  m: number;
  h: number;
  r: boolean;
  t: number;
}

/** Per question and attempt, for items from the questions table. */
export interface QuizResponse {
  questionId: string;
  attempt: number;
  isCorrect: boolean;
  answerId: string | null;
  responseMs: number | null;
}

export interface SyncResult {
  completed: boolean;
  score?: number;
  correctCount?: number;
  totalCount?: number;
  durationMs: number;
  metrics: {
    items: ItemMetric[];
    incorrect: number;
    hints: number;
    run: number;
    level?: string;
    [extra: string]: unknown;
  };
}

/** The `/play/sync` item. */
export interface SyncItem {
  session: {
    id: string;
    childId: string;
    activityId: string;
    lessonStepId?: string;
    source: PlaySource;
    platform: Platform;
    appVersion: string;
    contentVersion: number;
    status: SessionStatus;
    startedAt: string;
    endedAt?: string;
  };
  result?: SyncResult;
  responses?: QuizResponse[];
}

export interface ReportContext {
  source: PlaySource;
  platform?: Platform;
  appVersion: string;
  contentVersion?: number;
  /** More metrics merged into `result.metrics` (media positions etc.). */
  extra?: Record<string, unknown>;
}

const iso = (ms: number) => new Date(ms).toISOString();

function sessionPart(s: RunState, status: SessionStatus, c: ReportContext, endedAt: number | null): SyncItem["session"] {
  // Same keys, in the same order, as Dart's toJson; optional ones left out.
  return {
    id: s.sessionId,
    childId: s.childId,
    activityId: s.activityId,
    ...(s.lessonStepId !== null ? { lessonStepId: s.lessonStepId } : {}),
    source: c.source,
    platform: c.platform ?? "web",
    appVersion: c.appVersion,
    contentVersion: c.contentVersion ?? 1,
    status,
    startedAt: iso(s.startedAt),
    ...(endedAt !== null ? { endedAt: iso(endedAt) } : {}),
  };
}

/** Start report: sent when play begins, so a session that never finishes still exists. */
export function startedReport(s: RunState, c: ReportContext): SyncItem {
  return { session: sessionPart(s, "started", c, null) };
}

function answerIdOf(spec: ItemSpec, logged: Json): string | null {
  if (!("answerIds" in spec) || !Array.isArray(logged) || logged.length === 0) return null;
  const key = dartStr(logged[0]);
  return Object.prototype.hasOwnProperty.call(spec.answerIds, key) ? spec.answerIds[key] : null;
}

/** The quiz responses of a run (one per question and attempt, at most 20 attempts each). */
export function quizResponses(s: RunState): QuizResponse[] {
  const out: QuizResponse[] = [];
  s.items.forEach((item, i) => {
    if (item.questionId === null) return;
    const p = s.progress[i];
    for (let a = 0; a < p.answers.length && a < 20; a++) {
      const last = a === p.answers.length - 1;
      out.push({
        questionId: item.questionId,
        attempt: a + 1,
        isCorrect: p.correct && last,
        answerId: answerIdOf(item, p.answers[a]),
        responseMs: last ? p.spentMs : null,
      });
    }
  });
  return out;
}

/** The `result` object of an end report. */
export function buildResult(s: RunState, now: number, extra: Record<string, unknown> = {}): SyncResult {
  const completed = s.phase === "completed";
  const done = s.progress.filter(isDone).length;
  const metrics: SyncResult["metrics"] = {
    items: s.items.slice(0, 60).map((item, i) => ({
      k: item.kind,
      ok: s.progress[i].correct,
      w: s.progress[i].wrongAttempts,
      m: s.progress[i].mistakes,
      h: s.progress[i].hintLevel,
      r: s.progress[i].revealed,
      t: s.progress[i].spentMs,
    })),
    incorrect: incorrectCount(s),
    hints: hintsUsed(s),
    run: s.run,
  };
  if (s.level !== null) metrics.level = s.level;
  Object.assign(metrics, extra);
  // Key order as Dart: completed, score, correctCount, totalCount, durationMs, metrics.
  return {
    completed,
    ...(completed ? { score: scoreOf(s) } : {}),
    correctCount: correctCount(s),
    totalCount: completed ? s.items.length : done,
    durationMs: activeMsAt(s, now),
    metrics,
  };
}

/** End report: completed (every item done) or abandoned (left before the end). */
export function endedReport(s: RunState, now: number, c: ReportContext): SyncItem {
  const completed = s.phase === "completed";
  const item: SyncItem = {
    session: sessionPart(s, completed ? "completed" : "abandoned", c, s.endedAt ?? now),
    result: buildResult(s, now, c.extra ?? {}),
  };
  const responses = quizResponses(s);
  if (responses.length > 0) item.responses = responses;
  return item;
}

/** The request body for `POST /play/sync`. */
export function syncBody(items: SyncItem[], deviceId?: string): { deviceId?: string; items: SyncItem[] } {
  return deviceId === undefined ? { items } : { deviceId, items };
}
