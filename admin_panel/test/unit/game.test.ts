// The game builder writes the learning engine's format: every kind round-trips through the
// form, passes the engine's own JSON Schema, and is written as a fixture the Flutter app's
// contract test parses (kids_app/test/unit/admin_cms_contract_test.dart).
import { mkdirSync, writeFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { allItems, describe as say, formFromItem, itemFromForm, type GameConfig } from "@/lib/game/config";
import { GAME_TYPES, KINDS, kindOf } from "@/lib/game/kinds";
import { validateConfig } from "@/lib/game/validate";
import schema from "@/lib/game/game-config.schema.json";

/** Form input an editor would type for each kind. */
const SAMPLES: Record<string, Record<string, string>> = {
  multiple_choice: { prompt: "Which one is red?", options: "Apple\nBanana\nGrape", correct: "Apple", hint: "Think of a fruit for a teacher" },
  image_choice: { prompt: "Find the cat", options: "Cat | icon:cat\nDog | icon:dog", correct: "Cat" },
  audio_choice: { prompt: "Which animal says moo?", options: "Cow\nCat\nDuck", correct: "Cow" },
  fill_blank: { sentence: "The sun is ___", options: "hot\ncold", correct: "hot" },
  word_build: { word: "cat", extra: "x z", picture: "icon:cat", hint: "It says meow" },
  letter_recognition: { target: "b", mode: "name", distractors: "d p" },
  trace: { glyph: "a" },
  number_recognition: { count: "3", picture: "icon:apple" },
  arithmetic: { a: "2", op: "+", b: "3", picture: "icon:apple" },
  match_pairs: { prompt: "Match the pairs", pairs: "A = a\nB = b" },
  memory: { cards: "Sun | icon:sun\nMoon | icon:moon\nStar | icon:star", timer: "on" },
  sort: { prompt: "Fruit or toy?", bins: "Fruit\nToy", items: "Apple | icon:apple = Fruit\nBall | icon:ball = Toy" },
  drag_to_target: { prompt: "Put each one home", tokens: "bee\nfish", targets: "hive\nsea", solution: "bee = hive\nfish = sea" },
  puzzle: { picture: "char:pip", grid: "2" },
  jigsaw: { picture: "char:nova", grid: "3" },
  shape_complete: { shape: "star", missing: "left" },
};

describe("game builder (engine contract)", () => {
  it("covers every engine kind and the brief's game types", () => {
    const schemaKinds = [...(schema.$defs.item.properties.kind.enum as string[])].sort();
    expect(KINDS.map((k) => k.kind).sort()).toEqual(schemaKinds);
    expect(GAME_TYPES).toHaveLength(10);
    for (const t of GAME_TYPES) for (const k of t.kinds) expect(kindOf(k), k).toBeDefined();
    expect(Object.keys(SAMPLES).sort()).toEqual(schemaKinds);
  });

  for (const k of KINDS) {
    it(`${k.kind}: form → item is valid, and item → form → item is the same`, () => {
      const item = itemFromForm(k.kind, SAMPLES[k.kind]);
      expect(validateConfig({ items: [item] })).toEqual([]);
      expect(itemFromForm(k.kind, formFromItem(item))).toEqual(item);
      expect(say(item)).toContain(k.label);
    });
  }

  it("multiple choice stores the right answer as the option's id, and hints", () => {
    const item = itemFromForm("image_choice", SAMPLES.image_choice);
    expect(item.options).toEqual([{ id: "o1", label: "Cat", picture: "icon:cat" }, { id: "o2", label: "Dog", picture: "icon:dog" }]);
    expect(item.correct).toEqual(["o1"]);
    expect(itemFromForm("multiple_choice", SAMPLES.multiple_choice).hint).toBe("Think of a fruit for a teacher");
  });

  it("rejects what the app couldn't play", () => {
    expect(validateConfig({ items: [] })[0].message).toContain("at least one item");
    expect(validateConfig({ items: [{ kind: "multiple_choice", options: ["a", "b"] }] }).length).toBeGreaterThan(0); // no correct
    expect(validateConfig({ items: [{ kind: "arithmetic", a: 11, b: 1 }] }).length).toBeGreaterThan(0); // a > 10
    expect(validateConfig({ items: [{ kind: "teleport" }] }).length).toBeGreaterThan(0);
    const dup: GameConfig = { levels: [{ id: "easy", items: [{ kind: "trace", glyph: "a" }] }, { id: "easy", items: [{ kind: "trace", glyph: "b" }] }] };
    expect(validateConfig(dup).map((p) => p.message)).toContain("level ids must be different");
  });

  it("levels: easiest first, each with its own items", () => {
    const c: GameConfig = {
      intro: { text: "Let's count", speak: "Let's count" },
      levels: [
        { id: "easy", label: "Easy", minAgeMonths: 36, items: [itemFromForm("number_recognition", SAMPLES.number_recognition)] },
        { id: "hard", label: "Hard", minAgeMonths: 72, attempts: 2, items: [itemFromForm("arithmetic", SAMPLES.arithmetic)] },
      ],
    };
    expect(validateConfig(c)).toEqual([]);
    expect(allItems(c).map((x) => x.level)).toEqual(["easy", "hard"]);
  });

  it("writes one fixture game per kind for the Flutter contract test", () => {
    const dir = new URL("../../../kids_app/test/fixtures/admin_cms/", import.meta.url);
    mkdirSync(dir, { recursive: true });
    const all: GameConfig = {
      intro: { text: "Every kind", speak: "Every kind" },
      levels: [
        { id: "easy", label: "Easy", minAgeMonths: 0, items: KINDS.slice(0, 8).map((k) => itemFromForm(k.kind, SAMPLES[k.kind])) },
        { id: "hard", label: "Hard", minAgeMonths: 60, items: KINDS.slice(8).map((k) => itemFromForm(k.kind, SAMPLES[k.kind])) },
      ],
    };
    expect(validateConfig(all)).toEqual([]);
    writeFileSync(new URL("every_kind.json", dir), JSON.stringify(all, null, 1) + "\n");
  });
});
