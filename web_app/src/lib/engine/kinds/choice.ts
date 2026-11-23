/**
 * Pick the right option(s): multiple choice, image, audio, letter and number recognition,
 * fill the blank, arithmetic and shape completion (port of kinds/choice_kinds.dart). They differ
 * in content and look, not in rules.
 *
 * Answer: `{ type: "pick", ids: [optionId, …] }` — the selected option id(s).
 * No deviations from Dart.
 */
import {
  choicesFromJson,
  ctxRandom,
  dartClamp,
  dartStr,
  describePicture,
  en,
  makeChoice,
  makePrompt,
  optInt,
  optList,
  optMap,
  optString,
  picture,
  pictureFromJson,
  promptFromJson,
  promptSpoken,
  textFromJson,
  textIsEmpty,
  textOf,
} from "../common";
import { SeededRandom } from "../rng";
import type {
  ActivityKind,
  Choice,
  ChoiceKindKey,
  ChoiceSpec,
  ChoiceStyle,
  Equation,
  Hint,
  ItemAnswer,
  JsonMap,
  LocalizedText,
  ParseContext,
  Prompt,
  Verdict,
} from "../types";
import { ContentError, emptyText, right, wrong } from "../types";

function makeChoiceSpec(
  s: Pick<ChoiceSpec, "id" | "kind" | "prompt" | "options" | "correct"> &
    Partial<Omit<ChoiceSpec, "multi">>,
): ChoiceSpec {
  return {
    id: s.id,
    kind: s.kind,
    prompt: s.prompt,
    hintText: s.hintText ?? emptyText,
    questionId: s.questionId ?? null,
    options: s.options,
    correct: s.correct,
    style: s.style ?? "text",
    audioOnly: s.audioOnly ?? false,
    countPicture: s.countPicture ?? null,
    count: s.count ?? null,
    sentence: s.sentence ?? null,
    equation: s.equation ?? null,
    answerIds: s.answerIds ?? {},
    multi: s.correct.length > 1,
  };
}

function evaluateChoice(spec: ChoiceSpec, answer: ItemAnswer): Verdict {
  if (answer.type !== "pick") return wrong();
  const picked = new Set(answer.ids);
  const correct = new Set(spec.correct);
  if (picked.size === correct.size && [...correct].every((c) => picked.has(c))) return right();
  const hits = [...picked].filter((p) => correct.has(p)).length;
  return wrong(correct.size === 0 ? 0 : hits / correct.size);
}

/** Level 1: the item's hint (or a gentle default). Level 2: remove half the wrong options. */
function hintChoice(spec: ChoiceSpec, level: number): Hint {
  const text = textIsEmpty(spec.hintText) ? en("Listen again and look closely!") : spec.hintText;
  if (level <= 1) return { text, eliminate: [], reveal: [] };
  const correct = new Set(spec.correct);
  const wrongIds = spec.options.filter((o) => !correct.has(o.id)).map((o) => o.id);
  return { text, eliminate: [...new Set(wrongIds.slice(0, Math.ceil(wrongIds.length / 2)))], reveal: [] };
}

function choiceKind(key: ChoiceKindKey, parse: (json: JsonMap, ctx: ParseContext) => ChoiceSpec): ActivityKind<ChoiceSpec> {
  return {
    key,
    parse,
    evaluate: evaluateChoice,
    hint: hintChoice,
    solution: (spec) => ({ type: "pick", ids: [...spec.correct] }),
  };
}

/** Keeps every correct option and as many wrong ones as the policy allows, shuffled with the
 * item's seed (younger children see fewer options). */
export function trimAndShuffle(
  options: readonly Choice[],
  correct: ReadonlySet<string>,
  ctx: ParseContext,
  shuffle = true,
): Choice[] {
  const r = options.filter((o) => correct.has(o.id));
  const w = options.filter((o) => !correct.has(o.id));
  const keep = dartClamp(ctx.policy.maxOptions - r.length, 1, w.length);
  const picked = [...r, ...ctxRandom(ctx).shuffled(w).slice(0, keep)];
  return shuffle ? new SeededRandom(ctx.seed + 1).shuffled(picked) : picked;
}

function correctIds(v: unknown): string[] {
  if (Array.isArray(v)) return [...new Set(v.map(dartStr))];
  if (v === null || v === undefined) return [];
  return [dartStr(v)];
}

function answerIdsOf(v: unknown): Record<string, string> {
  const m = optMap(v, "answerIds");
  if (m === null) return {};
  const out: Record<string, string> = {};
  for (const [k, x] of Object.entries(m)) out[k] = dartStr(x);
  return out;
}

/** `{"kind":"multiple_choice","prompt":"Which one is round?","options":[…],"correct":["b"]}` */
function parseMultipleChoice(json: JsonMap, ctx: ParseContext, key: ChoiceKindKey = "multiple_choice"): ChoiceSpec {
  const correct = correctIds(json.correct);
  const options = choicesFromJson(json.options, "o");
  if (options.length < 2 || correct.length === 0 || !correct.every((c) => options.some((o) => o.id === c))) {
    throw new ContentError("multiple_choice needs 2+ options and a correct one");
  }
  const hasPictures = options.every((o) => o.picture !== null);
  return makeChoiceSpec({
    id: ctx.itemId,
    kind: key,
    prompt: promptFromJson(json.prompt),
    hintText: textFromJson(json.hint),
    options: trimAndShuffle(options, new Set(correct), ctx, json.shuffle !== false),
    correct,
    style: hasPictures ? "picture" : "text",
    questionId: optString(json.questionId, "questionId"),
    answerIds: answerIdsOf(json.answerIds),
  });
}

export const multipleChoiceKind = choiceKind("multiple_choice", (json, ctx) => parseMultipleChoice(json, ctx));

/** Pictures as options. (Like Dart, it keeps no question id / answer ids.) */
export const imageChoiceKind = choiceKind("image_choice", (json, ctx) => {
  const base = parseMultipleChoice(json, ctx);
  if (base.options.some((o) => o.picture === null)) throw new ContentError("image_choice options need pictures");
  return makeChoiceSpec({
    id: base.id,
    kind: "image_choice",
    prompt: base.prompt,
    hintText: base.hintText,
    options: base.options,
    correct: base.correct,
    style: "picture",
  });
});

/** The question is heard (a big "listen" button). */
export const audioChoiceKind = choiceKind("audio_choice", (json, ctx) => {
  const base = parseMultipleChoice(json, ctx);
  if (promptSpoken(base.prompt).length === 0) throw new ContentError("audio_choice needs something to say");
  return makeChoiceSpec({ ...base, kind: "audio_choice", audioOnly: true });
});

const LOOK_ALIKES: Readonly<Record<string, readonly string[]>> = {
  b: ["d", "p", "q"],
  d: ["b", "p", "q"],
  p: ["q", "b", "d"],
  q: ["p", "g", "d"],
  m: ["n", "w", "u"],
  n: ["m", "u", "h"],
  u: ["n", "v", "w"],
  a: ["o", "e", "c"],
  e: ["c", "o", "a"],
  c: ["o", "e", "a"],
  g: ["q", "y", "p"],
  h: ["n", "k", "b"],
  f: ["t", "l", "k"],
};

/** The sound each letter makes, and a word that starts with it. */
export const PHONICS: Readonly<Record<string, readonly [string, string]>> = {
  a: ["a", "apple"],
  b: ["buh", "ball"],
  c: ["kuh", "cat"],
  d: ["duh", "dog"],
  e: ["eh", "egg"],
  f: ["fff", "fish"],
  g: ["guh", "goat"],
  h: ["hhh", "hat"],
  i: ["ih", "insect"],
  j: ["juh", "jam"],
  k: ["kuh", "kite"],
  l: ["lll", "lion"],
  m: ["mmm", "moon"],
  n: ["nnn", "nest"],
  o: ["o", "octopus"],
  p: ["puh", "pig"],
  q: ["kwuh", "queen"],
  r: ["rrr", "rabbit"],
  s: ["sss", "sun"],
  t: ["tuh", "tiger"],
  u: ["uh", "umbrella"],
  v: ["vvv", "van"],
  w: ["wuh", "web"],
  x: ["ks", "fox"],
  y: ["yuh", "yo-yo"],
  z: ["zzz", "zebra"],
};

/** `{"kind":"letter_recognition","target":"b","mode":"name"|"sound"|"case","distractors":[…]}` */
export const letterRecognitionKind = choiceKind("letter_recognition", (json, ctx) => {
  const target = dartStr(json.target ?? "");
  if (target.length !== 1) throw new ContentError("letter_recognition needs a one-letter target");
  const mode = dartStr(json.mode ?? "name");
  const lower = target.toLowerCase();
  const upper = target !== lower;
  const sound = PHONICS[lower];
  if (mode === "sound" && sound === undefined) throw new ContentError(`no letter sound for "${target}"`);
  const given = optList(json.distractors, "distractors");
  const others = (
    given !== null
      ? given.map(dartStr)
      : (LOOK_ALIKES[lower] ?? ["o", "x", "s"]).map((l) => (upper ? l.toUpperCase() : l))
  ).filter((l) => l !== target);
  const options = [target, ...others].map((l) => makeChoice({ id: l, label: en(l) }));
  const other = upper ? lower : target.toUpperCase();
  let prompt: Prompt;
  if (json.prompt !== null && json.prompt !== undefined) prompt = promptFromJson(json.prompt);
  else if (mode === "sound") {
    const [s, word] = sound!;
    prompt = makePrompt({
      text: en("Which letter makes this sound?"),
      speak: en(`Which letter says ${s}? ${s}, like ${word}.`),
    });
  } else if (mode === "case") {
    prompt = makePrompt({
      text: en(upper ? `Find the big ${other}` : `Find the small ${other}`),
      speak: en(
        upper
          ? `Here is a small ${other}. Can you find the big one?`
          : `Here is a big ${other}. Can you find the small one?`,
      ),
      picture: picture(`glyph:${other}`),
    });
  } else {
    prompt = makePrompt({ text: en(`Find ${target}`), speak: en(`Can you find the letter ${target}?`) });
  }
  const hintText: LocalizedText =
    json.hint !== null && json.hint !== undefined
      ? textFromJson(json.hint)
      : mode === "sound"
        ? en(`${sound![1]} starts with ${sound![0]}`)
        : en(`${target} looks like this: ${target}`);
  return makeChoiceSpec({
    id: ctx.itemId,
    kind: "letter_recognition",
    prompt,
    hintText,
    options: trimAndShuffle(options, new Set([target]), ctx),
    correct: [target],
    style: "glyph",
    audioOnly: mode === "sound",
  });
});

/** `{"kind":"number_recognition","count":4,"picture":"icon:apple"}` or `{"target":7}`. */
export const numberRecognitionKind = choiceKind("number_recognition", (json, ctx) => {
  const count = optInt(json.count, "count");
  const target = optInt(json.target, "target") ?? count;
  if (target === null || target < 0 || target > 20) throw new ContentError("number_recognition needs 0..20");
  const given = optList(json.distractors, "distractors");
  const distractors =
    given !== null
      ? given.map((e) => optInt(e, "distractor") ?? (() => { throw new TypeError("distractor: null"); })())
      : [target - 1, target + 1, target + 2].filter((n) => n >= 0 && n <= 20);
  const options = [...new Set([target, ...distractors])].map((n) => makeChoice({ id: `${n}`, label: en(`${n}`) }));
  const pic = pictureFromJson(json.picture);
  if (count !== null && (pic === null || count > 10)) throw new ContentError("counting needs a picture and ≤ 10");
  const prompt =
    json.prompt !== null && json.prompt !== undefined
      ? promptFromJson(json.prompt)
      : count !== null
        ? makePrompt({ text: en("How many?"), speak: en("How many can you count?") })
        : makePrompt({ text: en(`Find ${target}`), speak: en(`Can you find the number ${target}?`) });
  return makeChoiceSpec({
    id: ctx.itemId,
    kind: "number_recognition",
    prompt,
    hintText: count !== null ? en("Touch each one as you count.") : en(`Listen: ${target}.`),
    options: trimAndShuffle(options, new Set([`${target}`]), ctx),
    correct: [`${target}`],
    style: "glyph",
    countPicture: count !== null ? pic : null,
    count,
  });
});

export const BLANK = "___";

/** `{"kind":"fill_blank","sentence":"The cow says ___","options":["moo","quack"],"correct":"moo"}` */
export const fillBlankKind = choiceKind("fill_blank", (json, ctx) => {
  const sentence = textFromJson(json.sentence);
  if (!textOf(sentence).includes(BLANK)) throw new ContentError("fill_blank sentence needs ___");
  const options = choicesFromJson(json.options, "o");
  const correct = correctIds(json.correct);
  if (correct.length !== 1 || !options.some((o) => o.id === correct[0])) {
    throw new ContentError("fill_blank needs exactly one correct option");
  }
  return makeChoiceSpec({
    id: ctx.itemId,
    kind: "fill_blank",
    prompt:
      json.prompt === null || json.prompt === undefined
        ? makePrompt({
            speak: en(textOf(sentence).split(BLANK).join("what?")),
            picture: pictureFromJson(json.picture),
          })
        : promptFromJson(json.prompt),
    hintText: textFromJson(json.hint),
    options: trimAndShuffle(options, new Set(correct), ctx),
    correct,
    sentence,
  });
});

const NUMBER_WORDS = [
  "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
  "nineteen", "twenty",
];

export function numberWord(n: number): string {
  return n >= 0 && n < NUMBER_WORDS.length ? NUMBER_WORDS[n] : `${n}`;
}

export function equationResult(e: Equation): number {
  return e.op === "-" ? e.a - e.b : e.a + e.b;
}

/** "3 + 2 = ?" */
export function equationText(e: Equation): string {
  return `${e.a} ${e.op === "-" ? "−" : "+"} ${e.b} = ?`;
}

/** What the voice asks. */
export function equationSpoken(e: Equation): string {
  const what = e.picture ? describePicture(e.picture) : null;
  if (what === null) return `What is ${numberWord(e.a)} ${e.op === "-" ? "take away" : "plus"} ${numberWord(e.b)}?`;
  return e.op === "-"
    ? `There are ${numberWord(e.a)} ${what}s. ${numberWord(e.b)} go away. How many are left?`
    : `${numberWord(e.a)} ${what}s and ${numberWord(e.b)} more. How many altogether?`;
}

/** `{"kind":"arithmetic","a":3,"op":"+","b":2,"picture":"icon:apple"}` */
export const arithmeticKind = choiceKind("arithmetic", (json, ctx) => {
  const a = optInt(json.a, "a");
  const b = optInt(json.b, "b");
  const op = dartStr(json.op ?? "+");
  if (a === null || b === null || a < 0 || b < 0 || a > 10 || b > 10) {
    throw new ContentError("arithmetic needs a and b between 0 and 10");
  }
  if (op !== "+" && op !== "-") throw new ContentError("arithmetic op is + or -");
  if (op === "-" && b > a) throw new ContentError("arithmetic: no answers below zero");
  const eq: Equation = { a, op, b, picture: pictureFromJson(json.picture) };
  const answer = equationResult(eq);
  const near = [...new Set([1, -1, 2, -2, 3].map((d) => answer + d))].filter((n) => n >= 0 && n <= 20).slice(0, 4);
  const options = [answer, ...near].map((n) => makeChoice({ id: `${n}`, label: en(`${n}`) }));
  return makeChoiceSpec({
    id: ctx.itemId,
    kind: "arithmetic",
    prompt:
      json.prompt !== null && json.prompt !== undefined
        ? promptFromJson(json.prompt)
        : makePrompt({
            text: en(eq.picture === null ? "What is the answer?" : equationText(eq)),
            speak: en(equationSpoken(eq)),
          }),
    hintText:
      json.hint !== null && json.hint !== undefined
        ? textFromJson(json.hint)
        : en(
            eq.picture === null
              ? op === "-"
                ? `Start at ${a} and count back ${b}.`
                : `Start at ${a} and count on ${b}.`
              : op === "-"
                ? "Count the ones that are left."
                : "Count all of them together.",
          ),
    options: trimAndShuffle(options, new Set([`${answer}`]), ctx),
    correct: [`${answer}`],
    style: "glyph",
    equation: eq,
  });
});

export const SHAPES = ["circle", "square", "triangle", "star", "heart"] as const;
export const SIDES = ["left", "right", "top", "bottom"] as const;

/** `{"kind":"shape_complete","shape":"heart","missing":"right","distractors":["circle","star"]}` */
export const shapeCompleteKind = choiceKind("shape_complete", (json, ctx) => {
  const shapes: readonly string[] = SHAPES;
  const sides: readonly string[] = SIDES;
  const shape = dartStr(json.shape ?? "");
  const side = dartStr(json.missing ?? "right");
  if (!shapes.includes(shape) || !sides.includes(side)) {
    throw new ContentError(`shape_complete needs a shape (${shapes.join(", ")}) and a side`);
  }
  const color = json.color === null || json.color === undefined ? "" : `?color=${dartStr(json.color)}`;
  const given = optList(json.distractors, "distractors");
  const others = (given ?? [...shapes]).map(dartStr).filter((d) => d !== shape && shapes.includes(d));
  if (others.length === 0) throw new ContentError("shape_complete needs another shape");
  const piece = (sh: string): Choice =>
    makeChoice({ id: sh, picture: picture(`half:${sh}:${side}${color}`), speak: en(`the ${side} side of a ${sh}`) });
  const style: ChoiceStyle = "picture";
  return makeChoiceSpec({
    id: ctx.itemId,
    kind: "shape_complete",
    prompt:
      json.prompt !== null && json.prompt !== undefined
        ? promptFromJson(json.prompt)
        : makePrompt({
            text: en(`Finish the ${shape}`),
            speak: en(`Which piece finishes the ${shape}?`),
            picture: picture(`gap:${shape}:${side}${color}`),
          }),
    hintText:
      json.hint !== null && json.hint !== undefined
        ? textFromJson(json.hint)
        : en(`Look at the edge. Which piece fits the ${shape}?`),
    options: trimAndShuffle([piece(shape), ...others.map(piece)], new Set([shape]), ctx),
    correct: [shape],
    style,
  });
});

export const choiceKinds: readonly ActivityKind<ChoiceSpec>[] = [
  multipleChoiceKind,
  imageChoiceKind,
  audioChoiceKind,
  letterRecognitionKind,
  numberRecognitionKind,
  fillBlankKind,
  arithmeticKind,
  shapeCompleteKind,
];
