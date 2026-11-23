/**
 * Activity content as stored (port of ActivitySource / GameLevel in session_report.dart and of
 * data/quiz_mapping.dart + SupabaseActivityContentRepository.sourceFromRow in play_data.dart).
 *
 * Deviations from Dart:
 * - Malformed `levels` / `items` containers throw ContentError (Dart throws a TypeError there).
 * - A question row may carry `image` / `audio` (signed URLs); like Dart's mapping they are
 *   accepted but not used (the engine only knows `icon:` / `shape:` … picture references).
 * - `activity` is reduced to an id (`activityId`); the UI keeps the catalogue row itself.
 */
import { asMap, dartStr, isMap, optInt, optList, promptFromJson, textFromJson } from "./common";
import type { KindRegistry } from "./registry";
import { stableHash } from "./rng";
import type { DifficultyPolicy, ItemSpec, Json, JsonMap, LocalizedText, Prompt } from "./types";
import { ContentError } from "./types";

/** One difficulty level of a game (`games.config.levels[]`), easiest first. */
export interface GameLevel {
  readonly id: string;
  readonly label: LocalizedText;
  /** The level picked first for a child this old (the hardest one they're old enough for). */
  readonly minAgeMonths: number;
  readonly maxOptions: number | null;
  readonly maxAttempts: number | null;
  readonly rawItems: readonly JsonMap[];
}

function rawItemsOf(v: unknown, what: string): JsonMap[] {
  try {
    return (optList(v, what) ?? []).map((e) => asMap(e, `${what}[]`));
  } catch (e) {
    throw new ContentError(e instanceof Error ? e.message : String(e));
  }
}

export function levelFromJson(j: JsonMap, index: number): GameLevel {
  try {
    return {
      id: dartStr(j.id ?? `level-${index + 1}`),
      label: textFromJson(j.label),
      minAgeMonths: optInt(j.minAgeMonths, "minAgeMonths") ?? 0,
      maxOptions: optInt(j.options, "options"),
      maxAttempts: optInt(j.attempts, "attempts"),
      rawItems: rawItemsOf(j.items, "items"),
    };
  } catch (e) {
    if (e instanceof ContentError) throw e;
    throw new ContentError(e instanceof Error ? e.message : String(e));
  }
}

/** The policy with the level's own number of options (or memory pairs) and tries. */
export function applyLevel(level: GameLevel | null, p: DifficultyPolicy): DifficultyPolicy {
  if (!level) return p;
  return { ...p, maxOptions: level.maxOptions ?? p.maxOptions, maxAttempts: level.maxAttempts ?? p.maxAttempts };
}

/** Content as stored; items are parsed per session (the session seed decides option order). */
export interface ActivitySource {
  readonly activityId: string;
  readonly intro: Prompt;
  readonly rawItems: readonly JsonMap[];
  readonly contentVersion: number;
  readonly difficulty: number;
  readonly levels: readonly GameLevel[];
  /** The level these rawItems belong to (null for a game without levels / no level chosen). */
  readonly levelId: string | null;
}

export interface FromConfigOptions {
  activityId: string;
  /** `games.config`: `{intro, items}` or `{intro, levels:[{id, label, minAgeMonths, options, attempts, items}]}`. */
  config: unknown;
  /** Items from the questions table (see `quizItems`). */
  extraItems?: readonly JsonMap[];
  contentVersion?: number;
  difficulty?: number;
}

/** Reads `games.config` plus items from the questions table (Dart ActivitySource.fromConfig). */
export function fromConfig(o: FromConfigOptions): ActivitySource {
  const config = isMap(o.config) ? o.config : {};
  const levels = rawItemsOf(config.levels, "levels")
    .map((l, i) => levelFromJson(l, i))
    .filter((l) => l.rawItems.length > 0);
  return {
    activityId: o.activityId,
    rawItems: [...rawItemsOf(config.items, "items"), ...(o.extraItems ?? [])],
    intro: promptFromJson(config.intro),
    contentVersion: o.contentVersion ?? 1,
    difficulty: o.difficulty ?? 1,
    levels,
    levelId: null,
  };
}

/** True when the engine can play it (it has items). */
export function isPlayable(s: ActivitySource): boolean {
  return s.rawItems.length > 0 || s.levels.length > 0;
}

/** The level being played. */
export function currentLevel(s: ActivitySource): GameLevel | null {
  return s.levels.find((l) => l.id === s.levelId) ?? null;
}

/** The harder level after the one being played, if any. */
export function nextLevel(s: ActivitySource): GameLevel | null {
  const i = s.levels.findIndex((l) => l.id === s.levelId);
  return i >= 0 && i < s.levels.length - 1 ? s.levels[i + 1] : null;
}

/** The hardest level a child of [ageMonths] is old enough for (else the first; null without levels). */
export function defaultLevel(s: ActivitySource, ageMonths: number): GameLevel | null {
  if (s.levels.length === 0) return null;
  for (let i = s.levels.length - 1; i >= 0; i--) if (s.levels[i].minAgeMonths <= ageMonths) return s.levels[i];
  return s.levels[0];
}

/** This content with the items of level [id] (unknown id or no levels: unchanged). Like Dart,
 * a level's items replace `config.items` and the extra (quiz) items. */
export function forLevel(s: ActivitySource, id: string | null | undefined): ActivitySource {
  const l = s.levels.find((x) => x.id === id);
  if (!l) return s;
  return { ...s, rawItems: l.rawItems, levelId: l.id };
}

/** Parses every item with a seed from the session id; throws ContentError when one can't be read. */
export function buildItems(s: ActivitySource, registry: KindRegistry, policy: DifficultyPolicy, sessionId: string): ItemSpec[] {
  const p = applyLevel(currentLevel(s), policy);
  const prefix = s.levelId === null ? "" : `${s.levelId}/`;
  return s.rawItems.map((raw, i) => {
    const q = raw.questionId;
    return registry.parseItem(raw, {
      itemId: `${prefix}${q === null || q === undefined ? `i${i}` : dartStr(q)}`,
      seed: stableHash(`${sessionId}/${prefix}${i}`),
      policy: p,
    });
  });
}

// --- Quiz mapping (questions / answers rows → engine items) -------------------------------

/** An `answers` row. */
export interface AnswerRow {
  id: string;
  position?: number | null;
  /** `{en: "cat"}`, `{picture: "icon:cat"}`, or both. */
  content?: JsonMap | null;
  is_correct?: boolean | null;
  match_key?: string | null;
  correct_order?: number | null;
  [extra: string]: unknown;
}

/** A `questions` row with its answers. */
export interface QuestionRow {
  id: string;
  type: string;
  /** Localised jsonb, e.g. `{en: "Which one is a?"}`. */
  prompt: Json;
  position?: number | null;
  difficulty?: number | null;
  /** Signed URL of prompt_image_asset_id; not used by the engine (as in Dart). */
  image?: string | null;
  /** Signed URL of prompt_audio_asset_id; not used by the engine (as in Dart). */
  audio?: string | null;
  answers?: readonly AnswerRow[] | null;
  [extra: string]: unknown;
}

const pos = (a: AnswerRow) => (typeof a.position === "number" ? Math.trunc(a.position) : 0);

function option(a: AnswerRow): JsonMap {
  const content: JsonMap = isMap(a.content) ? a.content : {};
  const label: JsonMap = { ...content };
  delete label.picture;
  const out: JsonMap = { id: a.id };
  if (Object.keys(label).length > 0) out.label = label;
  if (content.picture !== null && content.picture !== undefined) out.picture = content.picture;
  return out;
}

/** One question row (with its answers) → one engine item, or null for a type the engine can't play. */
export function itemFromQuestion(q: QuestionRow): JsonMap | null {
  const answers = [...(q.answers ?? [])].sort((a, b) => pos(a) - pos(b));
  const id = q.id;
  const prompt = q.prompt ?? null;
  switch (q.type) {
    case "single_choice":
    case "multi_choice":
    case "true_false":
    case "tap_target":
    case "listen_choose": {
      const answerIds: JsonMap = {};
      for (const a of answers) answerIds[dartStr(a.id)] = a.id;
      return {
        kind: q.type === "listen_choose" ? "audio_choice" : "multiple_choice",
        questionId: id,
        prompt: q.type === "listen_choose" ? { speak: prompt } : { text: prompt },
        options: answers.map(option),
        correct: answers.filter((a) => a.is_correct === true).map((a) => a.id),
        answerIds,
        shuffle: q.type !== "true_false",
      };
    }
    case "match": {
      const byKey = new Map<string, AnswerRow[]>();
      for (const a of answers) {
        const k = a.match_key;
        if (typeof k === "string") byKey.set(k, [...(byKey.get(k) ?? []), a]);
      }
      const pairs: Json[] = [...byKey.values()]
        .filter((p) => p.length === 2)
        .map((p) => ({ left: option(p[0]), right: option(p[1]) }));
      return pairs.length < 2 ? null : { kind: "match_pairs", questionId: id, prompt: { text: prompt }, pairs };
    }
    case "order": {
      const ord = (a: AnswerRow) => (typeof a.correct_order === "number" ? a.correct_order : 0);
      const ordered = [...answers].sort((a, b) => ord(a) - ord(b));
      return { kind: "puzzle", questionId: id, prompt: { text: prompt }, pieces: ordered.map(option) };
    }
    default:
      return null;
  }
}

/** Question rows (any order) → engine items, by `position`, unplayable types left out. */
export function quizItems(questions: readonly QuestionRow[]): JsonMap[] {
  const qp = (q: QuestionRow) => (typeof q.position === "number" ? q.position : 0);
  return [...questions]
    .sort((a, b) => qp(a) - qp(b))
    .map(itemFromQuestion)
    .filter((x): x is JsonMap => x !== null);
}

/** One `activities` row with `games(config)` and `questions(…, answers(…))` embedded (the
 * Flutter app's select) → a source. */
export function sourceFromRow(r: {
  id: string;
  games?: { config?: unknown } | { config?: unknown }[] | null;
  questions?: readonly QuestionRow[] | null;
  content_version?: number | null;
  difficulty?: number | null;
}): ActivitySource {
  const g = Array.isArray(r.games) ? (r.games.length === 0 ? null : r.games[0]) : r.games;
  return fromConfig({
    activityId: r.id,
    config: g?.config ?? {},
    extraItems: quizItems(r.questions ?? []),
    contentVersion: typeof r.content_version === "number" ? Math.trunc(r.content_version) : 1,
    difficulty: typeof r.difficulty === "number" ? Math.trunc(r.difficulty) : 1,
  });
}
