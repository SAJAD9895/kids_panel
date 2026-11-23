/**
 * Every activity type: parsing, judging answers, hints, the shown solution (port of
 * kids_app/test/unit/activity_kinds_test.dart and the kind tests of games_test.dart).
 */
import { describe, expect, it } from "vitest";
import {
  ALL_KINDS,
  type ChoiceSpec,
  ContentError,
  type DifficultyPolicy,
  type ItemAnswer,
  type ItemSpec,
  type JigsawSpec,
  type JsonMap,
  KNOWN_GLYPHS,
  type MemorySpec,
  type OrderSpec,
  type PickAnswer,
  type PlaceSpec,
  type Pt,
  type TraceAnswer,
  type TraceSpec,
  type Verdict,
  choiceSpoken,
  describePicture,
  fits,
  glyphStrokes,
  makePolicy,
  memory,
  order,
  pairOf,
  pick,
  pictureColor,
  pictureName,
  pictureScheme,
  pictureSize,
  place,
  policyForChild,
  promptSpoken,
  resample,
  standardRegistry,
  textIsEmpty,
  textOf,
  trace,
} from "@/lib/engine";
import { samplerItems } from "./engine-helpers";

const registry = standardRegistry();
const roomy = makePolicy({ maxOptions: 6 });
const parse = (json: JsonMap, o: { policy?: DifficultyPolicy; seed?: number } = {}): ItemSpec =>
  registry.parseItem(json, { itemId: "i0", seed: o.seed ?? 7, policy: o.policy ?? roomy });
const judge = (s: ItemSpec, a: ItemAnswer): Verdict => registry.evaluate(s, a);
const sampler = samplerItems();
const sample = (kind: string) => sampler.find((m) => m.kind === kind)!;

it("the standard registry has all 16 types, and the sampler uses each once", () => {
  expect(new Set(registry.keys)).toEqual(new Set(ALL_KINDS));
  expect(registry.keys).toHaveLength(16);
  expect(new Set(sampler.map((m) => m.kind))).toEqual(new Set(registry.keys));
});

it("every kind parses its sampler item; its solution is judged right", () => {
  for (const kind of ALL_KINDS) {
    const s = parse(sample(kind));
    expect(s.kind).toBe(kind);
    const sol = registry.solution(s);
    if (kind === "memory" || kind === "trace") {
      expect(sol, kind).toBeNull();
    } else {
      expect(sol, kind).not.toBeNull();
      expect(judge(s, sol!).correct, kind).toBe(true);
    }
  }
});

it("unknown types and broken content are refused, not crashed on", () => {
  expect(() => parse({ kind: "teleport" })).toThrow(ContentError);
  expect(() => parse({ kind: "teleport" })).toThrow("unknown kind teleport");
  expect(() => parse({ kind: "multiple_choice", options: ["a"] })).toThrow(ContentError);
  expect(() => parse({ kind: "trace", glyph: "€" })).toThrow(ContentError);
  expect(() => parse({ kind: "sort", bins: [{ id: "x" }], items: [] })).toThrow(ContentError);
  expect(() => parse({ kind: "fill_blank", sentence: "no blank", options: ["a"], correct: "a" })).toThrow(ContentError);
  // type errors inside a kind are wrapped, like Dart's `bad <kind> item <id>: …`
  expect(() => parse({ kind: "number_recognition", target: "7" })).toThrow(/^bad number_recognition item i0/);
  expect(() => parse({ kind: "sort", bins: ["a", "b"], items: ["x"] })).toThrow(ContentError);
  // every option correct: no wrong one to keep (Dart's clamp throws too)
  expect(() => parse({ kind: "multiple_choice", options: ["a", "b"], correct: ["a", "b"] })).toThrow(ContentError);
});

describe("choice types", () => {
  it("multiple choice: right, wrong, partial for multi-answer", () => {
    const s = parse(sample("multiple_choice"));
    expect(judge(s, pick("banana")).correct).toBe(true);
    expect(judge(s, pick("car")).correct).toBe(false);
    const multi = parse({ kind: "multiple_choice", prompt: "Pick the animals", options: ["cat", "dog", "car"], correct: ["cat", "dog"] }) as ChoiceSpec;
    expect(multi.multi).toBe(true);
    expect(judge(multi, pick("cat")).partial).toBe(0.5);
    expect(judge(multi, pick("cat", "dog")).correct).toBe(true);
    expect(judge(multi, pick("dog", "cat")).correct).toBe(true);
    expect(judge(multi, pick("cat", "dog", "car")).correct).toBe(false);
  });

  it("younger children see fewer options, the right one always stays", () => {
    for (let seed = 0; seed < 20; seed++) {
      const s = parse(
        { kind: "letter_recognition", target: "b", distractors: ["d", "p", "q", "h", "k"] },
        { policy: makePolicy({ maxOptions: 3 }), seed },
      ) as ChoiceSpec;
      expect(s.options).toHaveLength(3);
      expect(s.options.map((o) => o.id)).toContain("b");
    }
  });

  it("the same seed gives the same order (resume shows the same screen)", () => {
    const orderOf = (seed: number) => (parse(sample("image_choice"), { seed }) as ChoiceSpec).options.map((o) => o.id);
    expect(orderOf(42)).toEqual(orderOf(42));
  });

  it("image, audio, letter, number, fill-the-blank parse to the right shape", () => {
    expect((parse(sample("image_choice")) as ChoiceSpec).style).toBe("picture");
    const audio = parse(sample("audio_choice")) as ChoiceSpec;
    expect(audio.audioOnly).toBe(true);
    expect(promptSpoken(audio.prompt)).toBe("Find the cat.");
    const letter = parse(sample("letter_recognition")) as ChoiceSpec;
    expect(letter.style).toBe("glyph");
    expect(letter.correct).toEqual(["m"]);
    expect(promptSpoken(letter.prompt)).toContain("letter m");
    const count = parse({ kind: "number_recognition", count: 4, picture: "icon:apple" }) as ChoiceSpec;
    expect(count.count).toBe(4);
    expect(count.correct).toEqual(["4"]);
    expect(judge(count, pick("4")).correct).toBe(true);
    const blank = parse(sample("fill_blank")) as ChoiceSpec;
    expect(textOf(blank.sentence!)).toBe("The cow says ___");
    expect(judge(blank, pick("moo")).correct).toBe(true);
  });

  it("hints: words first, then wrong options greyed out; the solution is the right pick", () => {
    const s = parse(sample("multiple_choice"));
    expect(textOf(registry.hint(s, 1).text)).toBe("You can eat it!");
    const h2 = registry.hint(s, 2);
    expect(h2.eliminate.length).toBeGreaterThan(0);
    expect(h2.eliminate).not.toContain("banana");
    expect((registry.solution(s) as PickAnswer).ids).toEqual(["banana"]);
  });

  it("wrong answer type is simply wrong", () => {
    expect(judge(parse(sample("multiple_choice")), order(["banana"])).correct).toBe(false);
  });

  it("arithmetic: right answer, near-miss options, the words the voice says", () => {
    const s = parse({ kind: "arithmetic", a: 3, op: "+", b: 2, picture: "icon:apple" }) as ChoiceSpec;
    expect(s.correct).toEqual(["5"]);
    expect(s.options.map((o) => o.id)).toEqual(expect.arrayContaining(["5", "4", "6"]));
    expect(promptSpoken(s.prompt)).toContain("three apples and two more");
    expect(textOf(s.prompt.text)).toBe("3 + 2 = ?");
    expect(judge(s, pick("5")).correct).toBe(true);
    expect(judge(s, pick("4")).correct).toBe(false);
    const minus = parse({ kind: "arithmetic", a: 9, op: "-", b: 4 }) as ChoiceSpec;
    expect(minus.correct).toEqual(["5"]);
    expect(promptSpoken(minus.prompt)).toBe("What is nine take away four?");
    expect(textOf(minus.hintText)).toBe("Start at 9 and count back 4.");
    const bads: JsonMap[] = [{ a: 2, op: "-", b: 5 }, { a: 11, op: "+", b: 1 }, { a: 1, op: "*", b: 1 }, { a: 1 }];
    for (const bad of bads) {
      expect(() => parse({ kind: "arithmetic", ...bad })).toThrow(ContentError);
    }
  });

  it("letter sounds are heard; capitals and small letters are found in the same case", () => {
    const s = parse({ kind: "letter_recognition", target: "b", mode: "sound" }) as ChoiceSpec;
    expect(s.audioOnly).toBe(true);
    expect(promptSpoken(s.prompt)).toContain("buh, like ball");
    const big = parse({ kind: "letter_recognition", target: "B", mode: "case" }) as ChoiceSpec;
    expect(big.prompt.picture?.value).toBe("glyph:b");
    expect(big.options.every((o) => o.id === o.id.toUpperCase())).toBe(true);
    const small = parse({ kind: "letter_recognition", target: "g", mode: "case" }) as ChoiceSpec;
    expect(small.prompt.picture?.value).toBe("glyph:G");
    expect(promptSpoken(small.prompt)).toContain("find the small one");
  });

  it("shape completion: pick the half that finishes the shape", () => {
    const s = parse({ kind: "shape_complete", shape: "heart", missing: "right", distractors: ["star", "circle"] }) as ChoiceSpec;
    expect(s.prompt.picture?.value).toBe("gap:heart:right");
    expect(s.options.map((o) => o.picture!.value)).toEqual(
      expect.arrayContaining(["half:heart:right", "half:star:right", "half:circle:right"]),
    );
    expect(judge(s, pick("heart")).correct).toBe(true);
    expect(judge(s, pick("star")).correct).toBe(false);
    expect(() => parse({ kind: "shape_complete", shape: "blob" })).toThrow(ContentError);
  });
});

describe("placing types", () => {
  it("drag to target", () => {
    const s = parse(sample("drag_to_target")) as PlaceSpec;
    expect(fits(s, "fish", "water")).toBe(true);
    expect(fits(s, "fish", "tree")).toBe(false);
    expect(judge(s, place({ fish: "water", bird: "tree" })).correct).toBe(true);
    expect(judge(s, place({ fish: "water", bird: "tree" }, 2)).mistakes).toBe(2);
    expect(judge(s, place({ fish: "tree", bird: "water" })).correct).toBe(false);
    expect(judge(s, place({ fish: "water" })).correct, "not finished").toBe(false);
    expect(registry.hint(s, 2).reveal).toHaveLength(2);
  });

  it("sorting", () => {
    const s = parse(sample("sort")) as PlaceSpec;
    expect(s.targets.map((b) => b.id)).toEqual(["animals", "food"]);
    expect(judge(s, place({ cow: "animals", apple: "food", duck: "animals" })).correct).toBe(true);
    expect(judge(s, place({ cow: "food", apple: "food", duck: "animals" })).partial).toBeCloseTo(2 / 3, 9);
  });

  it("matching pairs", () => {
    const s = parse(sample("match_pairs")) as PlaceSpec;
    expect(s.tokens).toHaveLength(3);
    const right = { ...s.solution };
    expect(judge(s, place(right)).correct).toBe(true);
    expect(judge(s, place({ ...right, l0: right.l1, l1: right.l0 })).correct).toBe(false);
  });

  it("jigsaw: every piece has one place; wrong drops are mistakes", () => {
    const s = parse({ kind: "jigsaw", picture: "char:pip", grid: 3 }) as JigsawSpec;
    expect(s.tokens).toHaveLength(9);
    expect(s.targets).toHaveLength(9);
    expect(s.tokens.map((t) => t.id).join("")).not.toBe("p0p1p2p3p4p5p6p7p8");
    expect(fits(s, "p4", "s4")).toBe(true);
    expect(fits(s, "p4", "s5")).toBe(false);
    expect(choiceSpoken(s.targets[0])).toBe("top left");
    expect(choiceSpoken(s.targets[4])).toBe("middle");
    const all = Object.fromEntries(Array.from({ length: 9 }, (_, i) => [`p${i}`, `s${i}`]));
    const v = judge(s, place(all, 2));
    expect([v.correct, v.mistakes]).toEqual([true, 2]);
    expect(judge(s, place({ p0: "s0" })).correct).toBe(false);
    expect(registry.hint(s, 2).reveal).toHaveLength(2);
    const bads: JsonMap[] = [{ grid: 3 }, { picture: "char:pip", grid: 5 }];
    for (const bad of bads) {
      expect(() => parse({ kind: "jigsaw", ...bad })).toThrow(ContentError);
    }
  });
});

describe("ordering types", () => {
  it("word building: letters in order, look-alike pieces are interchangeable", () => {
    const s = parse({ kind: "word_build", word: "moon", extra: "x" }) as OrderSpec;
    expect(s.pieces).toHaveLength(5);
    expect(s.start.slice(0, 4).join(""), "never starts solved").not.toBe(s.order.join(""));
    expect(judge(s, order(["w0", "w1", "w2", "w3"])).correct).toBe(true);
    expect(judge(s, order(["w0", "w2", "w1", "w3"])).correct, "the two o letters swap freely").toBe(true);
    expect(judge(s, order(["w0", "w1", "w3", "w2"])).correct).toBe(false);
    expect(textOf(registry.hint(s, 1).text)).toBe("m … o … o … n");
    expect(registry.hint(s, 2).reveal).toEqual(["w0"]);
  });

  it("word building: an extra given as a list is read like Dart does (its printed form)", () => {
    const s = parse({ kind: "word_build", word: "cat", extra: ["x", "z"] }) as OrderSpec;
    expect(s.pieces.map((p) => textOf(p.label))).toEqual(["c", "a", "t", "[", "x", ",", "z", "]"]);
  });

  it("puzzle: a picture grid, or labelled pieces in order", () => {
    const s = parse(sample("puzzle")) as OrderSpec;
    expect([s.columns, s.pieces.length]).toEqual([2, 4]);
    expect(s.start.join("")).not.toBe(s.order.join(""));
    expect(judge(s, order([...s.order])).correct).toBe(true);
    expect(judge(s, order([...s.start])).correct).toBe(false);
    const story = parse({ kind: "puzzle", pieces: ["plant", "water", "grow"] }) as OrderSpec;
    expect(story.columns).toBe(0);
    expect(judge(story, order(["plant", "nonsense", "grow"])).correct, "unknown ids are wrong, not a crash").toBe(false);
    expect(judge(story, order(["plant", "water", "grow"])).correct).toBe(true);
  });
});

describe("memory", () => {
  it("pairs, extra flips as mistakes, hint shows one pair", () => {
    const s = parse(sample("memory")) as MemorySpec;
    expect(s.cards).toHaveLength(6);
    expect(s.pairs).toBe(3);
    expect(judge(s, memory(3, 3)).mistakes).toBe(0);
    expect(judge(s, memory(9, 3)).mistakes).toBe(3);
    expect(judge(s, memory(9, 2)).correct).toBe(false);
    const reveal = registry.hint(s, 2).reveal;
    expect(pairOf(reveal[0])).toBe(pairOf(reveal[1]));
  });

  it("younger children get fewer pairs", () => {
    const s = parse({ kind: "memory", cards: ["a", "b", "c", "d", "e"] }, { policy: makePolicy({ maxOptions: 3 }) }) as MemorySpec;
    expect(s.pairs).toBe(3);
  });
});

describe("tracing", () => {
  const follow = (s: TraceSpec, o: { dx?: number; dy?: number; keep?: number } = {}): TraceAnswer =>
    trace(
      s.strokes.map((stroke) => {
        const pts = resample(stroke, 0.02);
        return pts.slice(0, Math.ceil(pts.length * (o.keep ?? 1))).map((p) => ({ x: p.x + (o.dx ?? 0), y: p.y + (o.dy ?? 0) }));
      }),
    );

  it("following the path passes for every built-in glyph", () => {
    for (const g of KNOWN_GLYPHS.split("")) {
      const s = parse({ kind: "trace", glyph: g }) as TraceSpec;
      expect(judge(s, follow(s)).correct, `glyph ${g}`).toBe(true);
      expect(judge(s, follow(s, { dx: 0.03, dy: -0.03 })).correct, `a little wobble is fine (${g})`).toBe(true);
    }
  });

  it("scribbles, half a letter and a shifted letter fail", () => {
    const s = parse({ kind: "trace", glyph: "b" }) as TraceSpec;
    expect(judge(s, follow(s, { keep: 0.4 })).correct, "half done").toBe(false);
    expect(judge(s, follow(s, { dx: 0.3 })).correct, "next to the letter").toBe(false);
    const scribble: Pt[] = Array.from({ length: 40 }, (_, i) => ({ x: (i % 7) / 7, y: (i % 5) / 5 }));
    expect(judge(s, trace([scribble])).correct).toBe(false);
    expect(judge(s, trace([[{ x: 0.5, y: 0.5 }]])).correct, "a dot").toBe(false);
  });

  it("capitals can be traced, and a different letter fails", () => {
    const l = parse({ kind: "trace", glyph: "L" }) as TraceSpec;
    const t = parse({ kind: "trace", glyph: "T" }) as TraceSpec;
    const along = (s: TraceSpec) => trace(s.strokes.map((st) => resample(st, 0.02)));
    expect(judge(l, along(l)).correct).toBe(true);
    expect(judge(t, along(l)).correct).toBe(false);
    for (const c of "AEFHIKLMNOTUVWXYZC".split("")) expect(glyphStrokes(c), c).not.toBeNull();
  });

  it("custom strokes in content", () => {
    const s = parse({ kind: "trace", strokes: [[[0.2, 0.5], [0.8, 0.5]]] }) as TraceSpec;
    expect(judge(s, follow(s)).correct).toBe(true);
  });

  it("level 2 hint shows the start; younger children get a wider tolerance", () => {
    expect(registry.hint(parse(sample("trace")), 2).reveal).toEqual(["start"]);
    expect(policyForChild(40).traceTolerance).toBeGreaterThan(policyForChild(90).traceTolerance);
  });
});

it("difficulty policy by age", () => {
  const toddler = policyForChild(36);
  const reader = policyForChild(90, 3);
  expect([toddler.maxOptions, toddler.maxAttempts, toddler.autoSpeak]).toEqual([3, 3, true]);
  expect([reader.maxOptions, reader.maxAttempts, reader.autoSpeak]).toEqual([6, 2, false]);
});

describe("pictures", () => {
  it("modifiers are read, and named for screen readers", () => {
    const p = { value: "shape:circle?color=red&size=small" };
    expect([pictureScheme(p), pictureName(p), pictureColor(p), pictureSize(p)]).toEqual(["shape", "circle", "red", "small"]);
    expect(describePicture(p)).toBe("small red circle");
    const odd = { value: "icon:cat?color=pink&size=huge" };
    expect([pictureColor(odd), pictureSize(odd)], "unknown values are ignored").toEqual([null, null]);
    expect(describePicture({ value: "count:3:apple" })).toBe("3 apple");
    expect(describePicture({ value: "glyph:A" })).toBe("big A");
    expect(describePicture({ value: "glyph:a" })).toBe("small a");
    expect(textIsEmpty({ en: "  " })).toBe(true);
  });
});
