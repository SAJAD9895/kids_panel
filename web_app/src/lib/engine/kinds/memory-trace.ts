/**
 * Memory and tracing (port of kinds/memory_trace_kinds.dart).
 *
 * Answers:
 * - memory: `{ type: "memory", flips, pairsFound, timeMs? }` — sent once the board is played out
 *   (Dart doesn't judge the card sequence; the view runs the board and reports the counts).
 *   `flips` = pairs of cards turned, including misses. Right once every pair is found; flips
 *   beyond `2 × pairs` count as mistakes.
 * - trace: `{ type: "trace", strokes: [[{x, y}, …], …] }` in the unit square (0..1, origin top
 *   left). Judged geometrically exactly like Dart: coverage of the path, stray ink, ink length.
 * No deviations from Dart.
 */
import {
  choiceFromJson,
  ctxRandom,
  en,
  makeChoice,
  makePrompt,
  optList,
  optString,
  promptFromJson,
  textFromJson,
} from "../common";
import type { ActivityKind, Hint, ItemAnswer, MemorySpec, Pt, TraceSpec, Verdict } from "../types";
import { ContentError, right, wrong } from "../types";

// --- Memory --------------------------------------------------------------------------------

/** `cat#1` → `cat`. */
export function pairOf(cardId: string): string {
  return cardId.split("#")[0];
}

/** `{"kind":"memory","cards":[{"id":"cat","picture":"icon:cat"},…],"timer":true}` */
export const memoryKind: ActivityKind<MemorySpec> = {
  key: "memory",
  parse(json, ctx) {
    const raw = Array.isArray(json.cards) ? json.cards : [];
    const faces = raw.map((x, i) => choiceFromJson(x, `c${i}`));
    if (faces.length < 2 || faces.length > 8) throw new ContentError("memory needs 2..8 different cards");
    // Younger children get fewer pairs.
    const keep = faces.slice(0, Math.max(2, ctx.policy.maxOptions));
    const deck = keep.flatMap((f) => [makeChoice({ ...f, id: `${f.id}#1` }), makeChoice({ ...f, id: `${f.id}#2` })]);
    const cards = ctxRandom(ctx).shuffled(deck);
    return {
      id: ctx.itemId,
      kind: "memory",
      prompt: promptFromJson(json.prompt ?? { text: "Find the pairs", speak: "Turn two cards. Can you find the pairs?" }),
      hintText: textFromJson(json.hint),
      questionId: null,
      cards,
      timer: json.timer === true,
      pairs: Math.floor(cards.length / 2),
    };
  },
  evaluate(spec: MemorySpec, answer: ItemAnswer): Verdict {
    if (answer.type !== "memory" || answer.pairsFound < spec.pairs) return wrong();
    return right(Math.max(0, answer.flips - spec.pairs * 2));
  },
  /** Level 2: show where one pair is. */
  hint(spec: MemorySpec, level: number): Hint {
    const text = en("Try to remember where you saw each picture.");
    if (level <= 1) return { text, eliminate: [], reveal: [] };
    const first = spec.cards[0].id;
    const partner = spec.cards.find((c) => c.id !== first && pairOf(c.id) === pairOf(first));
    if (!partner) throw new Error("Bad state: No element");
    return { text, eliminate: [], reveal: [first, partner.id] };
  },
  solution: () => null,
};

// --- Tracing -------------------------------------------------------------------------------

export function dist(a: Pt, b: Pt): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

/** Points along a stroke every [step]. */
export function resample(stroke: readonly Pt[], step: number): Pt[] {
  if (stroke.length < 2) return [...stroke];
  const out: Pt[] = [stroke[0]];
  let carry = 0;
  for (let i = 1; i < stroke.length; i++) {
    const a = stroke[i - 1];
    const b = stroke[i];
    const len = dist(a, b);
    let d = step - carry;
    while (d <= len) {
      const t = d / len;
      out.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t });
      d += step;
    }
    carry = len - (d - step);
  }
  if (dist(out[out.length - 1], stroke[stroke.length - 1]) > step / 2) out.push(stroke[stroke.length - 1]);
  return out;
}

/** Points along the whole path every [step], used to check coverage. */
export function checkpoints(spec: TraceSpec, step = 0.04): Pt[] {
  return spec.strokes.flatMap((s) => resample(s, step));
}

/** Share of the path the finger must pass near, and the share of finger points allowed off it. */
export const MIN_COVERAGE = 0.75;
export const MAX_STRAY = 0.3;
/** Ink may be at most this many times the letter's length (stops scribbling over everything). */
export const MAX_INK_RATIO = 2.2;

const P = (x: number, y: number): Pt => ({ x, y });
const line = (x1: number, y1: number, x2: number, y2: number): Pt[] => [P(x1, y1), P(x2, y2)];

/** Arc around (cx, cy), radius rx × ry, from a1 to a2 degrees (0 = right, 90 = down). */
function arc(cx: number, cy: number, rx: number, ry: number, a1: number, a2: number, steps = 24): Pt[] {
  const out: Pt[] = [];
  for (let i = 0; i <= steps; i++) {
    const a = ((a1 + ((a2 - a1) * i) / steps) * Math.PI) / 180;
    out.push(P(cx + rx * Math.cos(a), cy + ry * Math.sin(a)));
  }
  return out;
}

/** Every letter and number with built-in strokes. */
export const KNOWN_GLYPHS = "abcdefgholx0123456789AEFHIKLMNOTUVWXYZC";

/** Built-in stroke paths, in the unit square, in the order a child writes them. */
export function glyphStrokes(glyph: string): Pt[][] | null {
  switch (glyph) {
    case "o":
    case "0":
      return [arc(0.5, 0.55, 0.28, 0.35, -90, 270)];
    case "O":
      return [arc(0.5, 0.5, 0.3, 0.4, -90, 270)];
    case "C":
      return [arc(0.55, 0.5, 0.3, 0.4, -40, -320)];
    case "U":
      return [[...line(0.3, 0.1, 0.3, 0.6), ...arc(0.5, 0.6, 0.2, 0.3, 180, 0), ...line(0.7, 0.6, 0.7, 0.1)]];
    case "A":
      return [line(0.5, 0.1, 0.25, 0.9), line(0.5, 0.1, 0.75, 0.9), line(0.34, 0.62, 0.66, 0.62)];
    case "E":
      return [line(0.32, 0.1, 0.32, 0.9), line(0.32, 0.1, 0.7, 0.1), line(0.32, 0.5, 0.62, 0.5), line(0.32, 0.9, 0.7, 0.9)];
    case "F":
      return [line(0.32, 0.1, 0.32, 0.9), line(0.32, 0.1, 0.7, 0.1), line(0.32, 0.5, 0.62, 0.5)];
    case "H":
      return [line(0.3, 0.1, 0.3, 0.9), line(0.7, 0.1, 0.7, 0.9), line(0.3, 0.5, 0.7, 0.5)];
    case "I":
      return [line(0.5, 0.1, 0.5, 0.9), line(0.35, 0.1, 0.65, 0.1), line(0.35, 0.9, 0.65, 0.9)];
    case "K":
      return [line(0.32, 0.1, 0.32, 0.9), [...line(0.7, 0.1, 0.32, 0.55), ...line(0.32, 0.55, 0.72, 0.9)]];
    case "L":
      return [[...line(0.35, 0.1, 0.35, 0.9), ...line(0.35, 0.9, 0.7, 0.9)]];
    case "M":
      return [[...line(0.22, 0.9, 0.22, 0.1), ...line(0.22, 0.1, 0.5, 0.6), ...line(0.5, 0.6, 0.78, 0.1), ...line(0.78, 0.1, 0.78, 0.9)]];
    case "N":
      return [[...line(0.28, 0.9, 0.28, 0.1), ...line(0.28, 0.1, 0.72, 0.9), ...line(0.72, 0.9, 0.72, 0.1)]];
    case "T":
      return [line(0.25, 0.1, 0.75, 0.1), line(0.5, 0.1, 0.5, 0.9)];
    case "V":
      return [[...line(0.25, 0.1, 0.5, 0.9), ...line(0.5, 0.9, 0.75, 0.1)]];
    case "W":
      return [[...line(0.16, 0.1, 0.33, 0.9), ...line(0.33, 0.9, 0.5, 0.4), ...line(0.5, 0.4, 0.67, 0.9), ...line(0.67, 0.9, 0.84, 0.1)]];
    case "X":
      return [line(0.27, 0.1, 0.73, 0.9), line(0.73, 0.1, 0.27, 0.9)];
    case "Y":
      return [line(0.25, 0.1, 0.5, 0.5), [...line(0.75, 0.1, 0.5, 0.5), ...line(0.5, 0.5, 0.5, 0.9)]];
    case "Z":
      return [[...line(0.28, 0.1, 0.72, 0.1), ...line(0.72, 0.1, 0.28, 0.9), ...line(0.28, 0.9, 0.72, 0.9)]];
    case "c":
      return [arc(0.52, 0.62, 0.26, 0.26, -40, -320)];
    case "a":
      return [arc(0.48, 0.64, 0.22, 0.24, -20, -380), line(0.7, 0.38, 0.7, 0.9)];
    case "b":
      return [line(0.32, 0.1, 0.32, 0.9), arc(0.52, 0.66, 0.2, 0.23, 180, 540)];
    case "d":
      return [arc(0.48, 0.66, 0.2, 0.23, 0, 360), line(0.68, 0.1, 0.68, 0.9)];
    case "e":
      return [[...line(0.28, 0.64, 0.74, 0.64), ...arc(0.51, 0.64, 0.23, 0.24, 0, -300)]];
    case "f":
      return [[...arc(0.62, 0.24, 0.14, 0.14, 0, -180).reverse(), ...line(0.48, 0.24, 0.48, 0.9)], line(0.34, 0.45, 0.66, 0.45)];
    case "g":
      return [arc(0.48, 0.45, 0.2, 0.2, 0, 360), [...line(0.68, 0.28, 0.68, 0.8), ...arc(0.5, 0.8, 0.18, 0.14, 0, 160)]];
    case "h":
      return [line(0.32, 0.1, 0.32, 0.9), [...arc(0.5, 0.6, 0.18, 0.18, 180, 360), ...line(0.68, 0.6, 0.68, 0.9)]];
    case "l":
      return [line(0.5, 0.1, 0.5, 0.9)];
    case "x":
      return [line(0.3, 0.35, 0.7, 0.9), line(0.7, 0.35, 0.3, 0.9)];
    case "1":
      return [[...line(0.36, 0.26, 0.54, 0.1), ...line(0.54, 0.1, 0.54, 0.9)]];
    case "2":
      return [[...arc(0.5, 0.32, 0.2, 0.2, 200, 380), ...line(0.68, 0.42, 0.3, 0.9), ...line(0.3, 0.9, 0.72, 0.9)]];
    case "3":
      return [[...arc(0.48, 0.3, 0.2, 0.18, 200, 450), ...arc(0.48, 0.68, 0.22, 0.2, -90, 160)]];
    case "4":
      return [[...line(0.6, 0.1, 0.26, 0.64), ...line(0.26, 0.64, 0.76, 0.64)], line(0.6, 0.36, 0.6, 0.9)];
    case "5":
      return [[...line(0.7, 0.1, 0.36, 0.1), ...line(0.36, 0.1, 0.33, 0.46), ...arc(0.5, 0.66, 0.22, 0.22, -120, 160)]];
    case "6":
      return [[...arc(0.52, 0.5, 0.24, 0.38, -60, -180), ...arc(0.5, 0.68, 0.2, 0.2, 180, 540)]];
    case "7":
      return [[...line(0.3, 0.1, 0.72, 0.1), ...line(0.72, 0.1, 0.42, 0.9)]];
    case "8":
      return [[...arc(0.5, 0.3, 0.17, 0.19, 90, 450), ...arc(0.5, 0.7, 0.21, 0.2, -90, 270)]];
    case "9":
      return [[...arc(0.5, 0.32, 0.2, 0.2, 0, 360), ...line(0.7, 0.32, 0.62, 0.9)]];
    default:
      return null;
  }
}

function strokeLength(s: readonly Pt[]): number {
  let n = 0;
  for (let i = 1; i < s.length; i++) n += dist(s[i - 1], s[i]);
  return n;
}

function readPoint(p: unknown): Pt {
  if (!Array.isArray(p)) throw new TypeError("trace point: expected [x, y]");
  const [x, y] = p as unknown[];
  if (typeof x !== "number" || typeof y !== "number") throw new TypeError("trace point: expected numbers");
  return P(x, y);
}

/** `{"kind":"trace","glyph":"a"}` or `{"kind":"trace","strokes":[[[0.5,0.1],[0.5,0.9]]]}` */
export const traceKind: ActivityKind<TraceSpec> = {
  key: "trace",
  parse(json, ctx) {
    const glyph = optString(json.glyph, "glyph");
    const raw = json.strokes;
    const strokes = Array.isArray(raw)
      ? raw.map((s) => (optList(s, "stroke") ?? (() => { throw new TypeError("stroke: null"); })()).map(readPoint))
      : glyph === null
        ? null
        : glyphStrokes(glyph);
    if (strokes === null || strokes.length === 0 || strokes.some((s) => s.length < 2)) {
      throw new ContentError(`trace needs strokes or a known glyph (got ${glyph ?? "none"})`);
    }
    return {
      id: ctx.itemId,
      kind: "trace",
      prompt:
        json.prompt === null || json.prompt === undefined
          ? makePrompt({
              text: en(glyph ?? ""),
              speak: en(glyph === null ? "Follow the dots" : `Trace the ${glyph}`),
            })
          : promptFromJson(json.prompt),
      hintText: textFromJson(json.hint),
      questionId: null,
      strokes,
      tolerance: ctx.policy.traceTolerance,
      glyph,
    };
  },
  evaluate(spec: TraceSpec, answer: ItemAnswer): Verdict {
    if (answer.type !== "trace") return wrong();
    const drawn = answer.strokes.flatMap((s) => resample(s, 0.02));
    if (drawn.length < 3) return wrong();
    const checks = checkpoints(spec);
    const covered = checks.filter((c) => drawn.some((d) => dist(d, c) <= spec.tolerance)).length / checks.length;
    const path = checkpoints(spec, 0.02);
    const stray = drawn.filter((d) => !path.some((c) => dist(c, d) <= spec.tolerance * 1.5)).length / drawn.length;
    const ink = answer.strokes.reduce((n, s) => n + strokeLength(s), 0);
    const want = spec.strokes.reduce((n, s) => n + strokeLength(s), 0);
    if (covered >= MIN_COVERAGE && stray <= MAX_STRAY && ink <= want * MAX_INK_RATIO) return right();
    return wrong(covered);
  },
  /** Level 1: words. Level 2: show where to start (the start dot pulses). */
  hint(_spec: TraceSpec, level: number): Hint {
    const text = en("Start at the green dot and follow the path.");
    return level <= 1 ? { text, eliminate: [], reveal: [] } : { text, eliminate: [], reveal: ["start"] };
  },
  solution: () => null,
};
