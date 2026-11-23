/**
 * Parity with the Flutter app's Dart engine: engine-parity.golden.json is produced by
 * engine-parity.golden.dart from every seeded game config and the admin CMS fixture, for three
 * ages and every level, plus one scripted run with its sync reports. The TS port must build
 * exactly the same items (ids, option order, shuffles, prompts, hints) and the same reports.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  type Choice,
  type Hint,
  type ItemSpec,
  type JsonMap,
  type KindRegistry,
  SessionEngine,
  applyLevel,
  buildItems,
  currentLevel,
  defaultLevel,
  endedReport,
  forLevel,
  fromConfig,
  makePolicy,
  memory,
  order,
  pick,
  policyForChild,
  standardRegistry,
  startedReport,
  toSnapshot,
} from "@/lib/engine";
import { everyKindConfig, here, seedConfigs } from "./engine-helpers";

const golden = JSON.parse(readFileSync(here("./engine-parity.golden.json"), "utf8")) as Record<string, unknown>;

const ch = (c: Choice) => ({ id: c.id, label: c.label, picture: c.picture?.value ?? null, speak: c.speak });
const hint = (h: Hint) => ({ text: h.text, eliminate: [...h.eliminate], reveal: [...h.reveal] });

function project(r: KindRegistry, s: ItemSpec): Record<string, unknown> {
  const out: Record<string, unknown> = {
    id: s.id,
    kind: s.kind,
    questionId: s.questionId,
    prompt: { text: s.prompt.text, speak: s.prompt.speak, picture: s.prompt.picture?.value ?? null },
    hintText: s.hintText,
    hint1: hint(r.hint(s, 1)),
    hint2: hint(r.hint(s, 2)),
  };
  switch (s.kind) {
    case "drag_to_target":
    case "sort":
    case "match_pairs":
      return { ...out, tokens: s.tokens.map(ch), targets: s.targets.map(ch), solution: s.solution };
    case "jigsaw":
      return { ...out, tokens: s.tokens.map(ch), targets: s.targets.map(ch), solution: s.solution, picture: s.picture.value, grid: s.grid };
    case "word_build":
    case "puzzle":
      return { ...out, pieces: s.pieces.map(ch), order: s.order, start: s.start, picture: s.picture?.value ?? null, columns: s.columns };
    case "memory":
      return { ...out, cards: s.cards.map(ch), timer: s.timer, pairs: s.pairs };
    case "trace":
      return {
        ...out,
        strokes: s.strokes.map((st) => st.length),
        firstPoint: [s.strokes[0][0].x, s.strokes[0][0].y],
        tolerance: s.tolerance,
        glyph: s.glyph,
      };
    default:
      return {
        ...out,
        options: s.options.map(ch),
        correct: s.correct,
        style: s.style,
        audioOnly: s.audioOnly,
        count: s.count,
        countPicture: s.countPicture?.value ?? null,
        sentence: s.sentence,
        answerIds: s.answerIds,
      };
  }
}

/** Rounds floats (trig in Dart and V8 may differ in the last bit). */
function norm(v: unknown): unknown {
  if (typeof v === "number") return Math.round(v * 1e9) / 1e9;
  if (Array.isArray(v)) return v.map(norm);
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, norm(x)]));
  return v;
}

describe("parity with the Dart engine (golden file)", () => {
  const registry = standardRegistry();
  const configs: Record<string, unknown> = {
    ...seedConfigs(),
    "admin-every-kind": everyKindConfig(),
  };

  it("covers every seeded game", () => {
    const keys = new Set(Object.keys(golden).filter((k) => !k.startsWith("__")).map((k) => k.split("|")[0]));
    expect(keys).toEqual(new Set(Object.keys(configs)));
    expect(Object.keys(configs).length).toBeGreaterThanOrEqual(17);
  });

  for (const [slug, config] of Object.entries(configs)) {
    it(`${slug}: same items, order, prompts and hints for every age and level`, () => {
      const base = fromConfig({ activityId: slug, config, difficulty: 2 });
      for (const age of [30, 60, 100]) {
        const levelIds = base.levels.length === 0 ? [null] : base.levels.map((l) => l.id);
        for (const lid of levelIds) {
          const src = forLevel(base, lid);
          const p = applyLevel(currentLevel(src), policyForChild(age, src.difficulty));
          const items = buildItems(src, registry, p, `sess-${age}`);
          const got = {
            defaultLevel: defaultLevel(base, age)?.id ?? null,
            policy: p,
            intro: { text: src.intro.text, speak: src.intro.speak },
            items: items.map((s) => project(registry, s)),
          };
          expect(norm(got), `${slug}|${age}|${lid ?? "-"}`).toEqual(norm(golden[`${slug}|${age}|${lid ?? "-"}`]));
        }
      }
    });
  }

  it("a scripted run reports exactly what the Flutter app reports", () => {
    const quizItem: JsonMap = {
      kind: "multiple_choice",
      questionId: "q1",
      prompt: { text: { en: "Which?" } },
      options: [
        { id: "a1", label: { en: "a" } },
        { id: "a2", label: { en: "b" } },
        { id: "a3", label: { en: "c" } },
      ],
      correct: ["a1"],
      answerIds: { a1: "a1", a2: "a2", a3: "a3" },
      shuffle: true,
    };
    const src = fromConfig({
      activityId: "x",
      config: {
        items: [
          { kind: "letter_recognition", target: "b" },
          quizItem,
          { kind: "memory", cards: ["a", "b", "c"] },
          { kind: "word_build", word: "cat" },
        ],
      },
    });
    const pol = makePolicy({ maxOptions: 4, maxAttempts: 2 });
    const eng = new SessionEngine(registry, pol);
    const t0 = Date.UTC(2026, 10, 18, 10);
    const at = (s: number) => t0 + s * 1000;
    let s = eng.begin(
      eng.create({ sessionId: "run-1", childId: "c", activityId: "x", items: buildItems(src, registry, pol, "run-1"), now: t0, level: "lv" }),
      t0,
    );
    s = eng.hint(s).state;
    s = eng.retry(eng.answer(s, pick("d"), at(3)).state, at(4));
    s = eng.next(eng.answer(s, pick("b"), at(6)).state, at(7));
    s = eng.retry(eng.answer(s, pick("a2"), at(9)).state, at(10));
    s = eng.next(eng.answer(s, pick("a3"), at(12)).state, at(13));
    s = eng.pause(s, at(14));
    s = eng.resume(s, at(40));
    s = eng.next(eng.answer(s, memory(9, 3, 20000), at(50)).state, at(51));
    const ctx = { source: "course" as const, platform: "web" as const, appVersion: "1.0.0", contentVersion: 3 };
    const mid = endedReport(s, at(52), ctx);
    s = eng.next(eng.answer(s, order(["w0", "w1", "w2"], 1), at(60)).state, at(61));
    const end = endedReport(s, at(62), ctx);
    const started = startedReport(s, { source: "feed", platform: "web", appVersion: "1.0.0" });
    const run = golden.__run as Record<string, unknown>;
    // Same keys in the same order, too (JSON.stringify compares order).
    expect(JSON.stringify(mid)).toBe(JSON.stringify(run.abandoned));
    expect(JSON.stringify(end)).toBe(JSON.stringify(run.completed));
    expect(JSON.stringify(started)).toBe(JSON.stringify(run.started));
    expect(toSnapshot(s, at(62))).toEqual(run.snapshot);
  });
});
