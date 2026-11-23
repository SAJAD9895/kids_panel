/**
 * Shared readers and helpers (port of the non-type parts of item_spec.dart and catalog.dart's
 * LocalizedText): localized text, pictures, prompts, choices, the difficulty policy, and a few
 * helpers that copy Dart's runtime behaviour so content parses to exactly the same items.
 *
 * Deviation: Dart's `'$value'` string interpolation is emulated by `dartStr` (lists print as
 * `[a, b]`, maps as `{k: v}`, null as `null`). A JSON number like `7.0` prints `7` here (JS can't
 * tell 7.0 from 7), where Dart would print `7.0`.
 */
import { SeededRandom } from "./rng";
import type {
  Choice,
  DifficultyPolicy,
  Json,
  JsonMap,
  LocalizedText,
  ParseContext,
  Picture,
  Prompt,
} from "./types";
import { emptyText } from "./types";

// --- Dart runtime helpers ------------------------------------------------------------------

/** Dart's `'$v'` for a JSON value. */
export function dartStr(v: unknown): string {
  if (v === null || v === undefined) return "null";
  if (typeof v === "string") return v;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  if (Array.isArray(v)) return `[${v.map(dartStr).join(", ")}]`;
  if (typeof v === "object") {
    return `{${Object.entries(v as Record<string, unknown>)
      .map(([k, x]) => `${k}: ${dartStr(x)}`)
      .join(", ")}}`;
  }
  return String(v);
}

export function isMap(v: unknown): v is JsonMap {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/** Dart `v as num?` then `.toInt()`: null stays null, a non-number is a type error. */
export function optInt(v: unknown, what: string): number | null {
  if (v === null || v === undefined) return null;
  if (typeof v !== "number") throw new TypeError(`${what}: expected a number, got ${dartStr(v)}`);
  return Math.trunc(v);
}

/** Dart `v as String?`. */
export function optString(v: unknown, what: string): string | null {
  if (v === null || v === undefined) return null;
  if (typeof v !== "string") throw new TypeError(`${what}: expected a string, got ${dartStr(v)}`);
  return v;
}

/** Dart `v as List?`. */
export function optList(v: unknown, what: string): Json[] | null {
  if (v === null || v === undefined) return null;
  if (!Array.isArray(v)) throw new TypeError(`${what}: expected a list`);
  return v as Json[];
}

/** Dart `v as Map?`. */
export function optMap(v: unknown, what: string): JsonMap | null {
  if (v === null || v === undefined) return null;
  if (!isMap(v)) throw new TypeError(`${what}: expected a map`);
  return v;
}

/** Dart `v as Map` (non-null). */
export function asMap(v: unknown, what: string): JsonMap {
  if (!isMap(v)) throw new TypeError(`${what}: expected a map`);
  return v;
}

/** Dart `int.clamp`, which throws when the range is empty. */
export function dartClamp(v: number, lo: number, hi: number): number {
  if (lo > hi) throw new RangeError(`Invalid argument(s): ${hi} < ${lo}`);
  return v < lo ? lo : v > hi ? hi : v;
}

// --- Localized text --------------------------------------------------------------------------

/** `{"en": "Cat"}`, or a plain string (taken as English); anything else is empty. */
export function textFromJson(json: unknown): LocalizedText {
  if (isMap(json)) {
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(json)) out[k] = dartStr(v);
    return out;
  }
  if (typeof json === "string") return { en: json };
  return emptyText;
}

export const en = (s: string): LocalizedText => ({ en: s });

/** Blank in every language. */
export function textIsEmpty(t: LocalizedText): boolean {
  return Object.values(t).every((v) => v.trim().length === 0);
}

/** The text in [locale], else English, else any, else ''. */
export function textOf(t: LocalizedText, locale = "en"): string {
  const v = t[locale] ?? t.en;
  if (v !== undefined) return v;
  const vals = Object.values(t);
  return vals.length === 0 ? "" : vals[0];
}

// --- Pictures ------------------------------------------------------------------------------

export const PICTURE_COLORS: ReadonlySet<string> = new Set(["red", "blue", "yellow", "green", "purple", "orange"]);
export const PICTURE_SIZES: ReadonlySet<string> = new Set(["small", "medium", "big"]);

export function pictureFromJson(v: unknown): Picture | null {
  return typeof v === "string" && v.includes(":") ? { value: v } : null;
}

export const picture = (value: string): Picture => ({ value });

function pictureBase(p: Picture): string {
  const q = p.value.indexOf("?");
  return q >= 0 ? p.value.substring(0, q) : p.value;
}

export function pictureScheme(p: Picture): string {
  const b = pictureBase(p);
  return b.substring(0, b.indexOf(":"));
}

export function pictureName(p: Picture): string {
  const b = pictureBase(p);
  return b.substring(b.indexOf(":") + 1);
}

/** Dart `Uri.splitQueryString` (last key wins, `+` is a space). */
export function pictureParams(p: Picture): Record<string, string> {
  const q = p.value.indexOf("?");
  if (q < 0) return {};
  const out: Record<string, string> = {};
  for (const part of p.value.substring(q + 1).split("&")) {
    if (part.length === 0) continue;
    const eq = part.indexOf("=");
    const dec = (s: string) => {
      try {
        return decodeURIComponent(s.replace(/\+/g, " "));
      } catch {
        return s;
      }
    };
    if (eq === -1) out[dec(part)] = "";
    else if (eq !== 0) out[dec(part.substring(0, eq))] = dec(part.substring(eq + 1));
  }
  return out;
}

export function pictureColor(p: Picture): string | null {
  const c = pictureParams(p).color;
  return c !== undefined && PICTURE_COLORS.has(c) ? c : null;
}

export function pictureSize(p: Picture): string | null {
  const s = pictureParams(p).size;
  return s !== undefined && PICTURE_SIZES.has(s) ? s : null;
}

/** Words for screen readers and the voice: "big red circle". */
export function describePicture(p: Picture): string {
  const scheme = pictureScheme(p);
  const name = pictureName(p);
  const parts = name.split(":");
  let what: string;
  if (scheme === "count") what = parts.join(" ");
  else if (scheme === "half" && parts.length > 1) what = `${parts[0]}, ${parts[1]} side`;
  else if (scheme === "gap" && parts.length > 1) what = `${parts[0]} with the ${parts[1]} side missing`;
  else if (scheme === "glyph" && name.length === 1 && name !== name.toLowerCase()) what = `big ${name}`;
  else if (scheme === "glyph" && name.length === 1 && name !== name.toUpperCase()) what = `small ${name}`;
  else what = name.replace(/-/g, " ");
  return [pictureSize(p), pictureColor(p), what].filter((x): x is string => x !== null).join(" ");
}

// --- Prompts and choices -------------------------------------------------------------------

export function makePrompt(p: Partial<Prompt> = {}): Prompt {
  return { text: p.text ?? emptyText, speak: p.speak ?? emptyText, picture: p.picture ?? null };
}

export function promptFromJson(json: unknown): Prompt {
  if (typeof json === "string") return makePrompt({ text: textFromJson(json) });
  const m = isMap(json) ? json : {};
  return makePrompt({
    text: textFromJson(m.text),
    speak: textFromJson(m.speak),
    picture: pictureFromJson(m.picture),
  });
}

/** What the voice reads for a prompt. */
export function promptSpoken(p: Prompt, locale = "en"): string {
  return textIsEmpty(p.speak) ? textOf(p.text, locale) : textOf(p.speak, locale);
}

export function makeChoice(c: Partial<Choice> & { id: string }): Choice {
  return { id: c.id, label: c.label ?? emptyText, picture: c.picture ?? null, speak: c.speak ?? emptyText };
}

export function choiceFromJson(json: unknown, fallbackId?: string): Choice {
  if (typeof json === "string") return makeChoice({ id: json, label: textFromJson(json) });
  const m = isMap(json) ? json : {};
  const rawId = m.id ?? fallbackId ?? m.label ?? m.picture;
  return makeChoice({
    id: dartStr(rawId),
    label: textFromJson(m.label),
    picture: pictureFromJson(m.picture),
    speak: textFromJson(m.speak),
  });
}

/** A list of choices with fallback ids `<prefix><index>`. */
export function choicesFromJson(v: unknown, prefix: string): Choice[] {
  const list = Array.isArray(v) ? v : [];
  return list.map((x, i) => choiceFromJson(x, `${prefix}${i}`));
}

/** The name read out for a choice (screen readers and the voice). */
export function choiceSpoken(c: Choice, locale = "en"): string {
  if (!textIsEmpty(c.speak)) return textOf(c.speak, locale);
  if (!textIsEmpty(c.label)) return textOf(c.label, locale);
  return c.picture ? describePicture(c.picture) : c.id;
}

// --- Difficulty policy -----------------------------------------------------------------------

export function makePolicy(p: Partial<DifficultyPolicy> = {}): DifficultyPolicy {
  return {
    maxAttempts: p.maxAttempts ?? 3,
    maxOptions: p.maxOptions ?? 4,
    autoSpeak: p.autoSpeak ?? true,
    offerHintAfterWrong: p.offerHintAfterWrong ?? true,
    traceTolerance: p.traceTolerance ?? 0.12,
  };
}

/** Pre-readers hear everything, see fewer options and get more tries; older children get more
 * options and a stricter trace. */
export function policyForChild(ageMonths: number, difficulty = 1): DifficultyPolicy {
  const young = ageMonths < 48;
  const preReader = ageMonths < 72;
  const hard = difficulty >= 3;
  return makePolicy({
    maxAttempts: preReader ? 3 : 2,
    maxOptions: young ? 3 : preReader ? (hard ? 4 : 3) : hard ? 6 : 4,
    autoSpeak: preReader,
    offerHintAfterWrong: ageMonths < 60,
    traceTolerance: young ? 0.16 : preReader ? 0.12 : 0.09,
  });
}

/** A fresh generator for the item's seed (Dart `ctx.random` makes a new one on every access). */
export function ctxRandom(ctx: ParseContext): SeededRandom {
  return new SeededRandom(ctx.seed);
}
