/**
 * The building blocks every activity type shares (port of kids_app
 * lib/features/play/domain/item_spec.dart): what is asked, what can be answered, how an answer is
 * judged and what a hint does. Plain data, no framework.
 *
 * Deviations from Dart:
 * - Dart classes become plain readonly objects; `Set`s become arrays (insertion order kept, the
 *   same order Dart iterates its LinkedHashSet in).
 * - Answers are a discriminated union on `type` (`pick` | `place` | `order` | `memory` | `trace`)
 *   instead of a sealed class hierarchy.
 * - Times are epoch milliseconds (numbers), not DateTime.
 */

/** JSON as read from `games.config` (or built by the quiz mapping). */
export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
export type JsonMap = { [key: string]: Json };

/** `{"en": "Cat", "es": "Gato"}`. */
export type LocalizedText = Readonly<Record<string, string>>;

export const emptyText: LocalizedText = Object.freeze({});

/** A picture by reference (`shape:circle`, `icon:cat?color=red&size=small`, `glyph:b`, …). */
export interface Picture {
  /** The raw reference, e.g. `shape:circle?color=red&size=small`. */
  readonly value: string;
}

/** What the child sees and hears for one item. */
export interface Prompt {
  readonly text: LocalizedText;
  readonly speak: LocalizedText;
  readonly picture: Picture | null;
}

/** Something tappable or draggable: an option, a card, a token, a tile. */
export interface Choice {
  readonly id: string;
  readonly label: LocalizedText;
  readonly picture: Picture | null;
  readonly speak: LocalizedText;
}

/** A point in the unit square (0..1, origin top-left). */
export interface Pt {
  readonly x: number;
  readonly y: number;
}

// --- Item specs ---------------------------------------------------------------------------

export type ChoiceKindKey =
  | "multiple_choice"
  | "image_choice"
  | "audio_choice"
  | "letter_recognition"
  | "number_recognition"
  | "fill_blank"
  | "arithmetic"
  | "shape_complete";
export type PlaceKindKey = "drag_to_target" | "sort" | "match_pairs";
export type OrderKindKey = "word_build" | "puzzle";
export type KindKey = ChoiceKindKey | PlaceKindKey | OrderKindKey | "jigsaw" | "memory" | "trace";

export const ALL_KINDS: readonly KindKey[] = [
  "multiple_choice",
  "image_choice",
  "audio_choice",
  "letter_recognition",
  "number_recognition",
  "fill_blank",
  "drag_to_target",
  "sort",
  "match_pairs",
  "word_build",
  "puzzle",
  "memory",
  "trace",
  "arithmetic",
  "shape_complete",
  "jigsaw",
];

interface ItemSpecBase {
  /** Stable per item: `i3`, `easy/i3`, or the question id. */
  readonly id: string;
  readonly prompt: Prompt;
  readonly hintText: LocalizedText;
  /** `questions.id` when the item came from the questions table (choice kinds only, like Dart). */
  readonly questionId: string | null;
}

export type ChoiceStyle = "text" | "picture" | "glyph";

/** A small sum shown with pictures: `3 + 2 = ?`. */
export interface Equation {
  readonly a: number;
  readonly op: "+" | "-";
  readonly b: number;
  readonly picture: Picture | null;
}

/** Pick the right option(s). */
export interface ChoiceSpec extends ItemSpecBase {
  readonly kind: ChoiceKindKey;
  readonly options: readonly Choice[];
  readonly correct: readonly string[];
  readonly style: ChoiceStyle;
  /** The prompt is heard, not read (a big "listen" button). */
  readonly audioOnly: boolean;
  /** Number recognition: show [count] of this picture to count. */
  readonly countPicture: Picture | null;
  readonly count: number | null;
  /** Fill the blank: the sentence with `___`. */
  readonly sentence: LocalizedText | null;
  readonly equation: Equation | null;
  /** Option id → `answers.id` (quiz items). */
  readonly answerIds: Readonly<Record<string, string>>;
  /** More than one correct option: the UI lets the child pick several. */
  readonly multi: boolean;
}

/** Put tokens where they belong (drag to target, sorting, matching pairs). */
export interface PlaceSpec extends ItemSpecBase {
  readonly kind: PlaceKindKey;
  readonly tokens: readonly Choice[];
  readonly targets: readonly Choice[];
  /** token id → target id */
  readonly solution: Readonly<Record<string, string>>;
}

/** A jigsaw: judged like drag and drop; tokens `p0..`, slots `s0..` (row by row). */
export interface JigsawSpec extends ItemSpecBase {
  readonly kind: "jigsaw";
  readonly tokens: readonly Choice[];
  readonly targets: readonly Choice[];
  readonly solution: Readonly<Record<string, string>>;
  readonly picture: Picture;
  /** Pieces per side (2, 3 or 4). */
  readonly grid: number;
}

/** Put pieces in the right order (letters of a word, parts of a picture). */
export interface OrderSpec extends ItemSpecBase {
  readonly kind: OrderKindKey;
  /** Every piece (word building may include extra letters that aren't used). */
  readonly pieces: readonly Choice[];
  /** The right order of piece ids. */
  readonly order: readonly string[];
  /** How the pieces are laid out at first (shuffled, never already solved). */
  readonly start: readonly string[];
  readonly picture: Picture | null;
  /** Puzzle grid width (0 for words and labelled ordering puzzles). */
  readonly columns: number;
}

/** Memory: cards face down; ids `<pair>#1` and `<pair>#2` make a pair. */
export interface MemorySpec extends ItemSpecBase {
  readonly kind: "memory";
  /** The deck, already shuffled. */
  readonly cards: readonly Choice[];
  /** Show a clock. */
  readonly timer: boolean;
  readonly pairs: number;
}

/** Tracing: follow a letter or number with a finger. */
export interface TraceSpec extends ItemSpecBase {
  readonly kind: "trace";
  /** The path to follow, as strokes in the unit square, in writing order. */
  readonly strokes: readonly (readonly Pt[])[];
  readonly tolerance: number;
  readonly glyph: string | null;
}

export type ItemSpec = ChoiceSpec | PlaceSpec | JigsawSpec | OrderSpec | MemorySpec | TraceSpec;

// --- Answers ------------------------------------------------------------------------------

/** Picked one or more options (every choice kind). */
export interface PickAnswer {
  readonly type: "pick";
  readonly ids: readonly string[];
}

/** Put things where they belong (drag to target, sort, match pairs, jigsaw). `mistakes` counts
 * the wrong drops the view already bounced back. */
export interface PlaceAnswer {
  readonly type: "place";
  readonly placements: Readonly<Record<string, string>>;
  readonly mistakes?: number;
}

/** Put things in order (word build, puzzle): the final arrangement of piece ids. */
export interface OrderAnswer {
  readonly type: "order";
  readonly ids: readonly string[];
  readonly mistakes?: number;
}

/** Memory: the board was played out. `flips` counts turned pairs, including misses. */
export interface MemoryAnswer {
  readonly type: "memory";
  readonly flips: number;
  readonly pairsFound: number;
  /** Time on the board when the clock showed. */
  readonly timeMs?: number | null;
}

/** Finger / mouse strokes in the unit square (tracing). Judged geometrically. */
export interface TraceAnswer {
  readonly type: "trace";
  readonly strokes: readonly (readonly Pt[])[];
}

export type ItemAnswer = PickAnswer | PlaceAnswer | OrderAnswer | MemoryAnswer | TraceAnswer;

export const pick = (...ids: string[]): PickAnswer => ({ type: "pick", ids });
export const place = (placements: Record<string, string>, mistakes = 0): PlaceAnswer => ({
  type: "place",
  placements,
  mistakes,
});
export const order = (ids: string[], mistakes = 0): OrderAnswer => ({ type: "order", ids, mistakes });
export const memory = (flips: number, pairsFound: number, timeMs?: number | null): MemoryAnswer => ({
  type: "memory",
  flips,
  pairsFound,
  timeMs,
});
export const trace = (strokes: Pt[][]): TraceAnswer => ({ type: "trace", strokes });

/** Compact, JSON-safe form for the progress log (identical to Dart's `ItemAnswer.toJson`). */
export function answerToJson(a: ItemAnswer): Json {
  switch (a.type) {
    case "pick":
      return [...new Set(a.ids)].sort();
    case "place":
      return { p: { ...a.placements }, m: a.mistakes ?? 0 };
    case "order":
      return { o: [...a.ids], m: a.mistakes ?? 0 };
    case "memory": {
      const out: JsonMap = { f: a.flips, p: a.pairsFound };
      if (a.timeMs != null) out.ms = a.timeMs;
      return out;
    }
    case "trace":
      return { s: a.strokes.length, n: a.strokes.reduce((n, s) => n + s.length, 0) };
  }
}

// --- Verdicts, hints, policy -------------------------------------------------------------

export interface Verdict {
  readonly correct: boolean;
  /** Wrong sub-moves inside a correct answer (bounced drops, extra memory flips). */
  readonly mistakes: number;
  /** 0..1: how close a wrong answer was. Informational. */
  readonly partial: number;
}

export const right = (mistakes = 0): Verdict => ({ correct: true, mistakes, partial: 1 });
export const wrong = (partial = 0): Verdict => ({ correct: false, mistakes: 0, partial });

/** Level 1 says something helpful; level 2 also narrows the choice or shows where to start. */
export interface Hint {
  readonly text: LocalizedText;
  /** Option ids to grey out (choice kinds). */
  readonly eliminate: readonly string[];
  /** Ids to highlight (the next tile, the first pair, `start` of a stroke). */
  readonly reveal: readonly string[];
}

export const noHint: Hint = Object.freeze({ text: emptyText, eliminate: [], reveal: [] });

export interface DifficultyPolicy {
  readonly maxAttempts: number;
  readonly maxOptions: number;
  readonly autoSpeak: boolean;
  readonly offerHintAfterWrong: boolean;
  /** How far (in the unit square) a finger may wander from the letter's path. */
  readonly traceTolerance: number;
}

/** Context for parsing: a stable id and seed for each item, and the difficulty policy. */
export interface ParseContext {
  readonly itemId: string;
  readonly seed: number;
  readonly policy: DifficultyPolicy;
}

/** Thrown when activity content can't be read (Dart: ContentException). */
export class ContentError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ContentError";
  }
}

/** One activity type: how to read its JSON, judge an answer, hint, and show the solution. */
export interface ActivityKind<S extends ItemSpec = ItemSpec> {
  readonly key: KindKey;
  parse(json: JsonMap, ctx: ParseContext): S;
  evaluate(spec: S, answer: ItemAnswer): Verdict;
  hint(spec: S, level: number): Hint;
  /** The correct answer, shown after the last try (null when it can't be shown). */
  solution(spec: S): ItemAnswer | null;
}
