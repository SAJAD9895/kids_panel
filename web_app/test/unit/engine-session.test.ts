/**
 * The run, levels, the /play/sync report and the quiz mapping (port of
 * kids_app/test/unit/session_engine_test.dart, games_test.dart levels / summary, and
 * admin_cms_contract_test.dart), plus every seeded game config and the admin CMS fixture.
 */
import { describe, expect, it } from "vitest";
import {
  type ActivitySource,
  type ChoiceSpec,
  ContentError,
  type JsonMap,
  type MemorySpec,
  type QuestionRow,
  SessionEngine,
  activeMsAt,
  applyLevel,
  attemptsOf,
  buildItems,
  celebrationStars,
  clock,
  correctCount,
  currentLevel,
  currentProgress,
  defaultLevel,
  endedReport,
  forLevel,
  fromConfig,
  hintsUsed,
  incorrectCount,
  isPlayable,
  itemFromQuestion,
  makePolicy,
  memory,
  nextLevel,
  pick,
  pointsOf,
  policyForChild,
  quizItems,
  runSummary,
  scoreOf,
  sourceFromRow,
  standardRegistry,
  startRun,
  startedReport,
  textOf,
  toSnapshot,
} from "@/lib/engine";
import { contentPackConfigs, everyKindConfig, seedConfigs } from "./engine-helpers";

const registry = standardRegistry();
const policy = makePolicy({ maxOptions: 4, maxAttempts: 3 });
const eng = new SessionEngine(registry, policy);
const t0 = Date.UTC(2026, 10, 18, 10);
const at = (s: number) => t0 + s * 1000;
const source = (items: JsonMap[]): ActivitySource => fromConfig({ activityId: "act", config: { items } });
const letters = source([
  { kind: "letter_recognition", target: "b" },
  { kind: "letter_recognition", target: "d" },
]);
const start = (id = "session-1", src = letters) =>
  eng.begin(eng.create({ sessionId: id, childId: "child", activityId: "act", items: buildItems(src, registry, policy, id), now: t0 }), t0);
const web = { source: "feed" as const, platform: "web" as const, appVersion: "1.0.0" };

describe("engine", () => {
  it("right first time: full marks, then the next item, then completed", () => {
    let s = start();
    expect([s.phase, s.index]).toEqual(["question", 0]);
    const { state: a, verdict } = eng.answer(s, pick("b"), at(4));
    expect(verdict.correct).toBe(true);
    expect([a.phase, a.feedback]).toEqual(["feedback", "correct"]);
    s = eng.next(a, at(5));
    expect(s.index).toBe(1);
    s = eng.next(eng.answer(s, pick("d"), at(9)).state, at(10));
    expect(s.phase).toBe("completed");
    expect([scoreOf(s), correctCount(s), incorrectCount(s), celebrationStars(s)]).toEqual([100, 2, 0, 3]);
    expect(s.endedAt).toBe(at(10));
    expect(s.progress[0].spentMs).toBe(4000);
  });

  it("wrong → try again → right: lower points, attempts counted", () => {
    let s = start();
    s = eng.answer(s, pick("d"), at(2)).state;
    expect(s.feedback).toBe("tryAgain");
    expect(eng.next(s, at(3)).index, "can't skip a try-again").toBe(0);
    s = eng.retry(s, at(3));
    expect(s.phase).toBe("question");
    s = eng.answer(s, pick("b"), at(5)).state;
    expect(attemptsOf(currentProgress(s))).toBe(2);
    expect(pointsOf(currentProgress(s))).toBe(0.75);
    expect(currentProgress(s).answers).toEqual([["d"], ["b"]]);
  });

  it("out of tries: the answer is revealed, the item scores 0, play goes on", () => {
    let s = start();
    for (let i = 0; i < 3; i++) {
      s = eng.answer(s, pick("d"), at(i * 2)).state;
      if (s.feedback === "tryAgain") s = eng.retry(s, at(i * 2 + 1));
    }
    expect(s.feedback).toBe("revealed");
    const p = currentProgress(s);
    expect([p.revealed, p.correct, pointsOf(p)]).toEqual([true, false, 0]);
    expect(eng.solution(s)).toEqual(pick("b"));
    expect(currentProgress(eng.answer(s, pick("b"), at(9)).state).correct, "no answers after the reveal").toBe(false);
    expect(eng.next(s, at(10)).index).toBe(1);
  });

  it("hints raise the level until there is nothing more, and cost points", () => {
    const s = start();
    const { state: a, hint: h1 } = eng.hint(s);
    expect(Object.keys(h1.text).length).toBeGreaterThan(0);
    const { state: b, hint: h2 } = eng.hint(a);
    expect(h2.eliminate.length).toBeGreaterThan(0);
    const { state: c } = eng.hint(b);
    expect(currentProgress(c).hintLevel, "no third level for choices").toBe(2);
    const d = eng.answer(c, pick("b"), at(3)).state;
    expect(pointsOf(currentProgress(d))).toBeCloseTo(0.8, 9);
    expect(hintsUsed(d)).toBe(2);
  });

  it("pauses do not count as time played", () => {
    let s = start();
    s = eng.pause(s, at(10));
    s = eng.resume(s, at(70));
    expect(activeMsAt(s, at(80))).toBe(20000);
  });

  it("snapshot → restore: same session, items and progress; finished items are skipped", () => {
    const s = eng.answer(start(), pick("d"), at(2)).state;
    const snap = JSON.parse(JSON.stringify(toSnapshot(s, at(3))));
    const items = buildItems(letters, registry, policy, snap.sessionId);
    const r = eng.restore(snap, items)!;
    expect([r.sessionId, r.index, r.phase]).toEqual(["session-1", 0, "question"]);
    expect(currentProgress(r).wrongAttempts).toBe(1);
    expect(r.activeMs).toBe(3000);
    const ids = (xs: readonly (typeof items)[number][]) => xs.map((i) => (i as ChoiceSpec).options.map((o) => o.id).join(""));
    expect(ids(r.items), "options in the same order (seeded by the session id)").toEqual(ids(s.items));
    let done = eng.retry(s, at(4));
    done = eng.answer(done, pick("b"), at(5)).state;
    const r2 = eng.restore(JSON.parse(JSON.stringify(toSnapshot(done, at(6)))), items)!;
    expect(r2.index, "continue with the next item").toBe(1);
  });

  it("restore refuses a snapshot when the content changed", () => {
    const snap = JSON.parse(JSON.stringify(toSnapshot(start(), at(1))));
    const other = buildItems(source([{ kind: "letter_recognition", target: "q" }]), registry, policy, "session-1");
    expect(eng.restore(snap, other)).toBeNull();
    expect(eng.restore({ ...snap, v: 99 }, buildItems(letters, registry, policy, "session-1"))).toBeNull();
  });

  it("play again: new session, everything reset, run counted", () => {
    const s = eng.next(eng.answer(start(), pick("b"), at(1)).state, at(2));
    const again = eng.again(s, { sessionId: "session-2", now: at(3) });
    expect([again.sessionId, again.run, again.index, correctCount(again)]).toEqual(["session-2", 2, 0, 0]);
  });

  it("an activity needs items", () => {
    expect(() => eng.create({ sessionId: "x", childId: "c", activityId: "a", items: [], now: t0 })).toThrow(ContentError);
  });
});

describe("session report (POST /play/sync item)", () => {
  it("start and end reports match the server contract", () => {
    let s = start();
    const started = startedReport(s, { source: "course", platform: "ios", appVersion: "1.0.0" });
    expect(started.result).toBeUndefined();
    expect(started.session.status).toBe("started");
    s = eng.next(eng.answer(s, pick("b"), at(2)).state, at(3));
    s = eng.next(eng.answer(s, pick("d"), at(5)).state, at(6));
    const json = JSON.parse(JSON.stringify(endedReport(s, at(6), { source: "course", platform: "ios", appVersion: "1.0.0" })));
    expect(new Set(Object.keys(json.session))).toEqual(
      new Set(["id", "childId", "activityId", "source", "platform", "appVersion", "contentVersion", "status", "startedAt", "endedAt"]),
    );
    expect(json.session.status).toBe("completed");
    expect(json.session.source).toBe("course");
    const r = json.result;
    expect([r.completed, r.score, r.correctCount, r.totalCount, r.durationMs]).toEqual([true, 100, 2, 2, 6000]);
    expect(r.metrics.items[0]).toMatchObject({ k: "letter_recognition" });
    expect(new TextEncoder().encode(JSON.stringify(r.metrics)).length, "activity_results.metrics limit").toBeLessThan(8192);
    expect(json.responses).toBeUndefined();
  });

  it('leaving early is "abandoned" with what was done so far (no score)', () => {
    const s = eng.answer(start(), pick("b"), at(2)).state;
    const r = endedReport(s, at(3), web);
    expect([r.session.status, r.result!.completed, "score" in r.result!, r.result!.totalCount]).toEqual(["abandoned", false, false, 1]);
  });

  it("score: retries, mistakes and hints lower it; revealed items score 0", () => {
    const src = source([
      { kind: "letter_recognition", target: "b" },
      { kind: "letter_recognition", target: "d" },
      { kind: "memory", cards: ["a", "b"] },
    ]);
    let s = start("s", src);
    s = eng.hint(s).state; // 0.9
    s = eng.next(eng.answer(s, pick("b"), at(1)).state, at(2));
    for (let i = 0; i < 3; i++) {
      s = eng.answer(s, pick("x"), at(3 + i)).state; // revealed → 0
      s = eng.retry(s, at(3 + i));
    }
    s = eng.next(s, at(7));
    s = eng.next(eng.answer(s, memory(6, 2), at(8)).state, at(9)); // 2 extra flips → 0.8
    expect(s.phase).toBe("completed");
    expect(scoreOf(s)).toBe(Math.round((100 * (0.9 + 0 + 0.8)) / 3));
    const r = endedReport(s, at(9), web).result!;
    expect([r.score, r.correctCount, r.totalCount]).toEqual([57, 2, 3]);
    expect([r.metrics.incorrect, r.metrics.hints]).toEqual([5, 1]);
  });

  it("quiz items report one response per question and attempt, with the answer id", () => {
    const quiz = source([
      itemFromQuestion({
        id: "q1",
        type: "single_choice",
        prompt: { en: "Which one is a?" },
        answers: [
          { id: "ans-a", position: 0, content: { en: "a" }, is_correct: true },
          { id: "ans-b", position: 1, content: { en: "b" }, is_correct: false },
        ],
      })!,
    ]);
    let s = start("session-1", quiz);
    s = eng.retry(eng.answer(s, pick("ans-b"), at(1)).state, at(2));
    s = eng.next(eng.answer(s, pick("ans-a"), at(3)).state, at(4));
    expect(endedReport(s, at(4), web).responses).toEqual([
      { questionId: "q1", attempt: 1, isCorrect: false, answerId: "ans-b", responseMs: null },
      { questionId: "q1", attempt: 2, isCorrect: true, answerId: "ans-a", responseMs: 2000 },
    ]);
  });
});

describe("quiz mapping", () => {
  it("choice, listen, match and order questions", () => {
    expect(itemFromQuestion({ id: "q", type: "listen_choose", prompt: { en: "Find the dog" }, answers: [] })!.kind).toBe("audio_choice");
    const tf = itemFromQuestion({ id: "q", type: "true_false", prompt: { en: "Sky is blue?" }, answers: [] })!;
    expect([tf.kind, tf.shuffle, tf.prompt]).toEqual(["multiple_choice", false, { text: { en: "Sky is blue?" } }]);
    const match = itemFromQuestion({
      id: "q",
      type: "match",
      prompt: { en: "Match" },
      answers: [
        { id: "1", position: 0, content: { en: "cat" }, match_key: "a" },
        { id: "2", position: 1, content: { picture: "icon:cat" }, match_key: "a" },
        { id: "3", position: 2, content: { en: "sun" }, match_key: "b" },
        { id: "4", position: 3, content: { picture: "icon:sun" }, match_key: "b" },
      ],
    })!;
    expect(match.kind).toBe("match_pairs");
    expect((match.pairs as JsonMap[])[0]).toEqual({ left: { id: "1", label: { en: "cat" } }, right: { id: "2", picture: "icon:cat" } });
    const ord = itemFromQuestion({
      id: "q",
      type: "order",
      prompt: { en: "In order" },
      answers: [
        { id: "x", position: 0, content: { en: "grow" }, correct_order: 2 },
        { id: "y", position: 1, content: { en: "plant" }, correct_order: 0 },
      ],
    })!;
    expect((ord.pieces as JsonMap[]).map((p) => p.id)).toEqual(["y", "x"]);
    expect(itemFromQuestion({ id: "q", type: "tap_somewhere_new", prompt: null, answers: [] })).toBeNull();
  });

  it("quizItems sorts by position, drops what can't be played, and the items parse", () => {
    const rows: QuestionRow[] = [
      { id: "q2", position: 1, type: "multi_choice", prompt: { en: "Pick two" }, difficulty: 1, image: null, audio: null,
        answers: [
          { id: "a", position: 0, content: { en: "a" }, is_correct: true },
          { id: "b", position: 1, content: { en: "b" }, is_correct: true },
          { id: "c", position: 2, content: { en: "c" }, is_correct: false },
        ] },
      { id: "q1", position: 0, type: "single_choice", prompt: { en: "Which?" }, difficulty: 1, image: "https://x/y.png", audio: null,
        answers: [
          { id: "b", position: 1, content: { en: "no" }, is_correct: false },
          { id: "a", position: 0, content: { en: "yes" }, is_correct: true },
        ] },
      { id: "q3", position: 2, type: "match", prompt: { en: "too few pairs" }, answers: [] },
    ];
    const items = quizItems(rows);
    expect(items.map((i) => i.questionId)).toEqual(["q1", "q2"]);
    const specs = buildItems(source(items), registry, policy, "s");
    expect(specs.map((s) => [s.id, s.questionId])).toEqual([["q1", "q1"], ["q2", "q2"]]);
    expect((specs[1] as ChoiceSpec).multi).toBe(true);
    expect(registry.evaluate(specs[1], pick("b", "a")).correct).toBe(true);
  });

  it("a Supabase row (games.config + questions) becomes a playable source", () => {
    const src = sourceFromRow({
      id: "a1",
      difficulty: 2,
      content_version: 3,
      games: { config: { intro: "Hello", items: [{ kind: "trace", glyph: "o" }] } },
      questions: [],
    });
    expect([isPlayable(src), src.difficulty, src.contentVersion, textOf(src.intro.text)]).toEqual([true, 2, 3, "Hello"]);
    expect(buildItems(src, registry, policy, "s")[0].kind).toBe("trace");
    expect(sourceFromRow({ id: "a2", games: [], questions: [] }).rawItems).toEqual([]);
  });
});

describe("levels", () => {
  const src = fromConfig({ activityId: "memory-match", config: seedConfigs()["memory-match"] });

  it("the starting level suits the child's age; Next level goes up one", () => {
    expect(src.levels.map((l) => l.id)).toEqual(["easy", "medium", "hard"]);
    expect(defaultLevel(src, 30)!.id).toBe("easy");
    expect(defaultLevel(src, 60)!.id).toBe("medium");
    expect(defaultLevel(src, 100)!.id).toBe("hard");
    expect(nextLevel(forLevel(src, "easy"))!.id).toBe("medium");
    expect(nextLevel(forLevel(src, "hard"))).toBeNull();
    expect(forLevel(src, "nope").levelId).toBeNull();
  });

  it("a level sets its own board size, whatever the child's age", () => {
    const young = policyForChild(30);
    const hard = forLevel(src, "hard");
    const m = buildItems(hard, registry, young, "s")[0] as MemorySpec;
    expect([m.pairs, m.timer]).toEqual([8, true]);
    expect(applyLevel(currentLevel(hard), young).maxOptions).toBe(8);
  });

  it("startRun picks the level by age and the level travels into the report", () => {
    const { engine, state, source: played, policy: p } = startRun({ source: src, registry, sessionId: "s1", childId: "c", ageMonths: 100, now: t0 });
    expect([played.levelId, state.level, state.phase, p.maxOptions]).toEqual(["hard", "hard", "intro", 8]);
    expect(state.items[0].id.startsWith("hard/")).toBe(true);
    let run = engine.begin(state, t0);
    const snap = JSON.parse(JSON.stringify(toSnapshot(run, t0)));
    expect(snap.level).toBe("hard");
    expect(engine.restore(snap, buildItems(played, registry, p, "s1"))!.level).toBe("hard");
    expect(engine.restore(snap, buildItems(forLevel(src, "easy"), registry, p, "s1")), "an Easy board isn't the saved Hard one").toBeNull();
    const { state: done, verdict } = engine.answer(run, memory(10, 8, 42000), t0 + 50000);
    expect([verdict.correct, verdict.mistakes]).toEqual([true, 0]);
    run = engine.next(done, t0 + 55000);
    expect(endedReport(run, t0 + 55000, web).result!.metrics.level).toBe("hard");
    const easy = startRun({ source: src, registry, sessionId: "s2", childId: "c", ageMonths: 100, levelId: "easy", now: t0 });
    expect(easy.state.level).toBe("easy");
  });

  it("a game without levels keeps working as before", () => {
    const plain = fromConfig({ activityId: "x", config: { items: [{ kind: "letter_recognition", target: "b" }] } });
    expect(plain.levels).toEqual([]);
    expect(defaultLevel(plain, 60)).toBeNull();
    expect(buildItems(forLevel(plain, null), registry, makePolicy({ maxOptions: 6 }), "s")[0].id).toBe("i0");
    expect(startRun({ source: plain, registry, sessionId: "s", childId: "c", now: t0 }).state.level).toBeNull();
  });

  it("completion summary: right answers, and for memory the moves and time", () => {
    const easy = forLevel(src, "easy");
    const e = new SessionEngine(registry, applyLevel(currentLevel(easy), makePolicy({ maxOptions: 6 })));
    let run = e.begin(e.create({ sessionId: "s", childId: "c", activityId: "memory-match", items: buildItems(easy, registry, makePolicy({ maxOptions: 6 }), "s"), now: t0 }), t0);
    for (const t of [21000, 33000]) run = e.next(e.answer(run, memory(4, 3, t), t0).state, t0);
    expect(runSummary(run).lines).toEqual(["2 of 2 right", "8 moves", "Time 0:54"]);
    expect(clock(125000)).toBe("2:05");
  });
});

describe("content in the repo", () => {
  it("the admin-built game has levels, an intro and every kind; each has a solution but trace and memory", () => {
    const src = fromConfig({ activityId: "admin-every-kind", config: everyKindConfig() });
    expect(src.levels.map((l) => l.id)).toEqual(["easy", "hard"]);
    const kinds = new Set<string>();
    let n = 0;
    for (const level of src.levels) {
      for (const raw of level.rawItems) {
        const spec = registry.parseItem(raw, { itemId: `i${n++}`, seed: 3, policy: makePolicy({ maxOptions: 6 }) });
        kinds.add(spec.kind);
        if (spec.kind !== "trace" && spec.kind !== "memory") expect(registry.solution(spec), spec.kind).not.toBeNull();
      }
    }
    expect(kinds).toEqual(new Set(registry.keys));
  });

  it("every game in the content packs (supabase/content) plays: each level, each age, each item solvable", () => {
    const configs = contentPackConfigs();
    expect(Object.keys(configs).length).toBeGreaterThanOrEqual(9);
    const seeded = new Set(Object.keys(seedConfigs()));
    let n = 0;
    for (const [slug, config] of Object.entries(configs)) {
      expect(seeded.has(slug), `${slug} is also in seed.sql`).toBe(false);
      const base = fromConfig({ activityId: slug, config });
      expect(isPlayable(base), slug).toBe(true);
      expect(base.levels.length, `${slug} has Easy/Medium/Hard`).toBeGreaterThanOrEqual(2);
      for (const age of [24, 48, 72, 108]) {
        for (const level of base.levels) {
          const src = forLevel(base, level.id);
          expect(() => buildItems(src, registry, policyForChild(age), "s"), `${slug}/${level.id} at ${age} months`).not.toThrow();
        }
      }
      for (const level of base.levels) {
        for (const raw of level.rawItems) {
          const spec = registry.parseItem(raw, { itemId: `i${n++}`, seed: 7, policy: makePolicy({ maxOptions: 6 }) });
          if (spec.kind !== "trace" && spec.kind !== "memory") expect(registry.solution(spec), `${slug}/${level.id}/${spec.kind}`).not.toBeNull();
        }
      }
    }
  });

  it("every published game config in seed.sql parses, for every level and age", () => {
    const configs = seedConfigs();
    expect(Object.keys(configs).length).toBeGreaterThanOrEqual(16);
    for (const [slug, config] of Object.entries(configs)) {
      const base = fromConfig({ activityId: slug, config });
      expect(isPlayable(base), slug).toBe(true);
      const levelIds = base.levels.length === 0 ? [null] : base.levels.map((l) => l.id);
      for (const age of [24, 48, 72, 108]) {
        for (const lid of levelIds) {
          const src = forLevel(base, lid);
          expect(() => buildItems(src, registry, policyForChild(age), "s"), `${slug}/${lid} at ${age} months`).not.toThrow();
        }
      }
    }
  });
});
