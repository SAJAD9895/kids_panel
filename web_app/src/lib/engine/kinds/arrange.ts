/**
 * Placing and ordering kinds (port of kinds/arrange_kinds.dart): drag to target, sort, match
 * pairs, jigsaw (placing) and word build, puzzle (ordering).
 *
 * Answers:
 * - drag_to_target: `{ type: "place", placements: { tokenId: targetId }, mistakes }`
 * - sort:           `{ type: "place", placements: { itemId: binId }, mistakes }`
 * - match_pairs:    `{ type: "place", placements: { leftId: rightId }, mistakes }` (ids `l0…`, `r0…`)
 * - jigsaw:         `{ type: "place", placements: { "p3": "s3", … }, mistakes }`
 * - word_build / puzzle: `{ type: "order", ids: [pieceId, …], mistakes }` (the final arrangement)
 * `mistakes` = wrong drops the view already bounced back (they cost points but don't fail).
 *
 * Kept from Dart on purpose (parity): `extra` for word_build is read as Dart's `'$extra'`, so an
 * array `["x","z"]` becomes the letters `[`, `x`, `,`, `z`, `]` exactly as the Flutter app shows.
 */
import {
  asMap,
  choiceFromJson,
  choicesFromJson,
  ctxRandom,
  dartStr,
  en,
  makeChoice,
  optInt,
  optMap,
  pictureFromJson,
  promptFromJson,
  makePrompt,
  textFromJson,
  textIsEmpty,
  textOf,
} from "../common";
import type {
  ActivityKind,
  Choice,
  Hint,
  ItemAnswer,
  JigsawSpec,
  JsonMap,
  OrderKindKey,
  OrderSpec,
  ParseContext,
  PlaceKindKey,
  PlaceSpec,
  Verdict,
} from "../types";
import { ContentError, right, wrong } from "../types";

type Placing = PlaceSpec | JigsawSpec;

/** Does [tokenId] belong on [targetId]? (For bouncing wrong drops back in the view.) */
export function fits(spec: Placing, tokenId: string, targetId: string): boolean {
  return spec.solution[tokenId] === targetId;
}

function evaluatePlace(spec: Placing, answer: ItemAnswer): Verdict {
  if (answer.type !== "place") return wrong();
  const entries = Object.entries(spec.solution);
  const ok = entries.filter(([k, v]) => Object.prototype.hasOwnProperty.call(answer.placements, k) && answer.placements[k] === v).length;
  if (ok === entries.length && Object.keys(answer.placements).length === entries.length) {
    return right(answer.mistakes ?? 0);
  }
  return wrong(ok / entries.length);
}

/** Level 1: words. Level 2: show where the first token goes. */
function hintPlace(spec: Placing, level: number): Hint {
  const text = textIsEmpty(spec.hintText) ? en("Look at the shapes and colours.") : spec.hintText;
  if (level <= 1) return { text, eliminate: [], reveal: [] };
  const [k, v] = Object.entries(spec.solution)[0];
  return { text, eliminate: [], reveal: [...new Set([k, v])] };
}

function placeKind<S extends Placing>(key: S["kind"], parse: (json: JsonMap, ctx: ParseContext) => S): ActivityKind<S> {
  return {
    key,
    parse,
    evaluate: evaluatePlace,
    hint: hintPlace,
    solution: (spec) => ({ type: "place", placements: { ...spec.solution }, mistakes: 0 }),
  };
}

function makePlaceSpec(kind: PlaceKindKey, json: JsonMap, ctx: ParseContext, defaultPrompt: Record<string, string>, tokens: Choice[], targets: Choice[], solution: Record<string, string>): PlaceSpec {
  return {
    id: ctx.itemId,
    kind,
    prompt: promptFromJson(json.prompt ?? defaultPrompt),
    hintText: textFromJson(json.hint),
    questionId: null,
    tokens,
    targets,
    solution,
  };
}

/** `{"kind":"drag_to_target","tokens":[…],"targets":[…],"solution":{"t":"tt"}}` */
export const dragToTargetKind = placeKind<PlaceSpec>("drag_to_target", (json, ctx) => {
  const tokens = choicesFromJson(json.tokens, "t");
  const targets = choicesFromJson(json.targets, "g");
  const solution: Record<string, string> = {};
  for (const [k, v] of Object.entries(optMap(json.solution, "solution") ?? {})) solution[k] = dartStr(v);
  if (
    tokens.length === 0 ||
    tokens.some((t) => !Object.prototype.hasOwnProperty.call(solution, t.id)) ||
    Object.values(solution).some((g) => !targets.some((t) => t.id === g))
  ) {
    throw new ContentError("drag_to_target: every token needs a target");
  }
  return makePlaceSpec("drag_to_target", json, ctx, { text: "Put each one in its place" }, ctxRandom(ctx).shuffled(tokens), targets, solution);
});

/** `{"kind":"sort","bins":[{"id":"fruit","label":"Fruit"}],"items":[{"id":"apple","bin":"fruit"}]}` */
export const sortKind = placeKind<PlaceSpec>("sort", (json, ctx) => {
  const bins = choicesFromJson(json.bins, "b");
  const raw = Array.isArray(json.items) ? json.items : [];
  const items = raw.map((x, i) => choiceFromJson(x, `i${i}`));
  const solution: Record<string, string> = {};
  raw.forEach((x, i) => {
    solution[items[i].id] = dartStr(asMap(x, "sort item").bin);
  });
  if (bins.length < 2 || items.length === 0 || Object.values(solution).some((b) => !bins.some((x) => x.id === b))) {
    throw new ContentError("sort needs 2+ bins and items that each name a bin");
  }
  return makePlaceSpec("sort", json, ctx, { text: "Sort them!" }, ctxRandom(ctx).shuffled(items), bins, solution);
});

/** `{"kind":"match_pairs","pairs":[{"left":{"picture":"icon:cow"},"right":{"label":"cow"}}]}`.
 * Ids are always `l<i>` / `r<i>` (the content's own ids are not kept, like Dart). */
export const matchPairsKind = placeKind<PlaceSpec>("match_pairs", (json, ctx) => {
  const raw = Array.isArray(json.pairs) ? json.pairs : [];
  if (raw.length < 2) throw new ContentError("match_pairs needs 2+ pairs");
  const lefts: Choice[] = [];
  const rights: Choice[] = [];
  const solution: Record<string, string> = {};
  raw.forEach((x, i) => {
    const m = asMap(x, "pair");
    const l = choiceFromJson(m.left, `l${i}`);
    const r = choiceFromJson(m.right, `r${i}`);
    lefts.push(makeChoice({ ...l, id: `l${i}` }));
    rights.push(makeChoice({ ...r, id: `r${i}` }));
    solution[`l${i}`] = `r${i}`;
  });
  return makePlaceSpec("match_pairs", json, ctx, { text: "Find the pairs" }, lefts, ctxRandom(ctx).shuffled(rights), solution);
});

/** Board position (0-based, row by row) of a piece or slot id like `p5` / `s5`. */
export function jigsawIndexOf(id: string): number {
  return parseInt(id.substring(1), 10);
}

/** `{"kind":"jigsaw","picture":"char:pip","grid":3}` */
export const jigsawKind = placeKind<JigsawSpec>("jigsaw", (json, ctx) => {
  const pic = pictureFromJson(json.picture);
  const grid = optInt(json.grid, "grid") ?? 2;
  if (pic === null) throw new ContentError("jigsaw needs a picture");
  if (grid < 2 || grid > 4) throw new ContentError("jigsaw grid is 2, 3 or 4");
  const n = grid * grid;
  const where = (i: number): string => {
    const row = Math.floor(i / grid);
    const col = i % grid;
    const v = row === 0 ? "top" : row === grid - 1 ? "bottom" : "middle";
    const h = col === 0 ? "left" : col === grid - 1 ? "right" : "middle";
    return v === h ? "middle" : `${v} ${h}`;
  };
  const tokens = Array.from({ length: n }, (_, i) => makeChoice({ id: `p${i}`, speak: en(`piece ${i + 1}`) }));
  const solution: Record<string, string> = {};
  for (let i = 0; i < n; i++) solution[`p${i}`] = `s${i}`;
  return {
    id: ctx.itemId,
    kind: "jigsaw",
    prompt: promptFromJson(
      json.prompt ?? { text: "Build the picture", speak: "Put each piece where it belongs to make the picture." },
    ),
    hintText: json.hint === null || json.hint === undefined ? en("Start with a corner piece.") : textFromJson(json.hint),
    questionId: null,
    tokens: ctxRandom(ctx).shuffled(tokens),
    targets: Array.from({ length: n }, (_, i) => makeChoice({ id: `s${i}`, speak: en(where(i)) })),
    solution,
    picture: pic,
    grid,
  };
});

// --- Ordering ------------------------------------------------------------------------------

export function pieceOf(spec: OrderSpec, id: string): Choice {
  const p = spec.pieces.find((x) => x.id === id);
  if (!p) throw new Error(`Bad state: No element ${id}`);
  return p;
}

/** Pieces with the same face (two "o"s in "moon") are interchangeable; an unknown id is wrong. */
function evaluateOrder(spec: OrderSpec, answer: ItemAnswer): Verdict {
  if (answer.type !== "order") return wrong();
  const known = new Set(spec.pieces.map((p) => p.id));
  if (!answer.ids.every((id) => known.has(id))) return wrong();
  const face = (id: string) => textOf(pieceOf(spec, id).label);
  const got = answer.ids.map(face);
  const want = spec.order.map(face);
  let same = 0;
  for (let i = 0; i < want.length && i < got.length; i++) if (got[i] === want[i]) same++;
  if (got.length === want.length && same === want.length) return right(answer.mistakes ?? 0);
  return wrong(want.length === 0 ? 0 : same / want.length);
}

function orderKind(
  key: OrderKindKey,
  parse: (json: JsonMap, ctx: ParseContext) => OrderSpec,
  hint: (spec: OrderSpec, level: number) => Hint,
): ActivityKind<OrderSpec> {
  return { key, parse, evaluate: evaluateOrder, hint, solution: (spec) => ({ type: "order", ids: [...spec.order], mistakes: 0 }) };
}

/** `{"kind":"word_build","word":"cat","picture":"icon:cat","extra":"o"}` */
export const wordBuildKind = orderKind(
  "word_build",
  (json, ctx) => {
    const word = dartStr(json.word ?? "").trim();
    if (word.length === 0 || word.length > 8) throw new ContentError("word_build needs a word of 1..8 letters");
    const letters = word.split("");
    const extra = dartStr(json.extra ?? "")
      .split("")
      .filter((c) => c.trim().length > 0);
    const pieces = [
      ...letters.map((l, i) => makeChoice({ id: `w${i}`, label: en(l) })),
      ...extra.map((l, i) => makeChoice({ id: `x${i}`, label: en(l) })),
    ];
    const order = letters.map((_, i) => `w${i}`);
    let start = ctxRandom(ctx).shuffled(pieces.map((p) => p.id));
    if (start.slice(0, order.length).join("") === order.join("") && start.length > 1) {
      start = [...start.slice(1), start[0]];
    }
    const pic = pictureFromJson(json.picture);
    return {
      id: ctx.itemId,
      kind: "word_build",
      prompt:
        json.prompt === null || json.prompt === undefined
          ? makePrompt({ speak: en(`Spell ${word}`), picture: pic })
          : promptFromJson(json.prompt),
      hintText: textFromJson(json.hint),
      questionId: null,
      pieces,
      order,
      start,
      picture: pic,
      columns: 0,
    };
  },
  /** Level 1: say the word slowly. Level 2: light up the next letter. */
  (spec, level) => {
    const word = spec.order.map((id) => textOf(pieceOf(spec, id).label)).join("");
    const text = en(word.split("").join(" … "));
    return level <= 1 ? { text, eliminate: [], reveal: [] } : { text, eliminate: [], reveal: [spec.order[0]] };
  },
);

/** `{"kind":"puzzle","picture":"char:pip","grid":2}` or labelled `pieces` (an ordering puzzle). */
export const puzzleKind = orderKind(
  "puzzle",
  (json, ctx) => {
    const pic = pictureFromJson(json.picture);
    const labelled = choicesFromJson(json.pieces, "p");
    const g = optInt(json.grid, "grid") ?? 2;
    const grid = g < 2 ? 2 : g > 4 ? 4 : g;
    const pieces =
      labelled.length > 0
        ? labelled
        : Array.from({ length: grid * grid }, (_, i) => makeChoice({ id: `p${i}`, label: en(`${i + 1}`) }));
    if (labelled.length === 0 && pic === null) throw new ContentError("puzzle needs a picture or pieces");
    const order = pieces.map((p) => p.id);
    let start = ctxRandom(ctx).shuffled(order);
    if (start.join("") === order.join("")) start = [...start.slice(1), start[0]];
    return {
      id: ctx.itemId,
      kind: "puzzle",
      prompt: promptFromJson(json.prompt ?? { text: "Fix the picture" }),
      hintText: textFromJson(json.hint),
      questionId: null,
      pieces,
      order,
      start,
      picture: pic,
      columns: labelled.length === 0 ? grid : 0,
    };
  },
  /** Level 2: show where the first piece belongs. */
  (spec, level) => {
    const text = en("Start with the top corner.");
    return level <= 1
      ? { text: textIsEmpty(spec.hintText) ? text : spec.hintText, eliminate: [], reveal: [] }
      : { text, eliminate: [], reveal: [spec.order[0]] };
  },
);

export const arrangeKinds: readonly (ActivityKind<PlaceSpec> | ActivityKind<JigsawSpec> | ActivityKind<OrderSpec>)[] = [
  dragToTargetKind,
  sortKind,
  matchPairsKind,
  wordBuildKind,
  puzzleKind,
  jigsawKind,
];

