// Game configs (games.config, validated against the engine schema before saving) and quiz
// questions (questions + answers rows, which the app turns into engine items).
import { AdminError, must, mustOne } from "../errors";
import type { GameConfig } from "../game/config";
import { validateConfig } from "../game/validate";
import { type Db, en, withEn, type Row } from "./db";

export async function getGameConfig(db: Db, activityId: string): Promise<GameConfig> {
  const g = must(await db.from("games").select("config").eq("activity_id", activityId).maybeSingle());
  return (g?.config as GameConfig) ?? { items: [] };
}

/** Saves a config only if the engine schema accepts it. */
export async function saveGameConfig(db: Db, activityId: string, config: GameConfig) {
  const problems = validateConfig(config);
  if (problems.length) throw new AdminError(`The game isn't valid yet: ${problems.map((p: Row) => `${p.path} ${p.message}`).join("; ")}`);
  mustOne(await db.from("games").update({ config }).eq("activity_id", activityId).select("activity_id"));
}

export type Answer = { id: string; position: number; text: string; correct: boolean; imageAssetId: string | null; audioAssetId: string | null };
export type Question = { id: string; position: number; type: string; prompt: string; difficulty: number; imageAssetId: string | null; audioAssetId: string | null; answers: Answer[] };

export async function listQuestions(db: Db, activityId: string): Promise<Question[]> {
  const rows = must(await db.from("questions")
    .select("id, position, type, prompt, difficulty, prompt_image_asset_id, prompt_audio_asset_id, answers(id, position, content, is_correct, image_asset_id, audio_asset_id)")
    .eq("activity_id", activityId).order("position"));
  return rows.map((q: Row) => ({
    id: q.id, position: q.position, type: q.type, prompt: en(q.prompt), difficulty: q.difficulty,
    imageAssetId: q.prompt_image_asset_id, audioAssetId: q.prompt_audio_asset_id,
    answers: (q.answers ?? []).map((a: { id: string; position: number; content: unknown; is_correct: boolean; image_asset_id: string | null; audio_asset_id: string | null }) => ({
      id: a.id, position: a.position, text: en(a.content), correct: a.is_correct, imageAssetId: a.image_asset_id, audioAssetId: a.audio_asset_id,
    })).sort((x: Answer, y: Answer) => x.position - y.position),
  }));
}

export type QuestionInput = { prompt: string; type: "single_choice" | "multi_choice" | "true_false" | "listen_choose"; difficulty: number; imageAssetId: string | null; audioAssetId: string | null; answers: { text: string; correct: boolean }[] };

export function checkQuestion(q: QuestionInput): string[] {
  const out: string[] = [];
  if (!q.prompt.trim()) out.push("Write the question");
  const answers = q.answers.filter((a) => a.text.trim());
  if (answers.length < 2) out.push("Give at least two answers");
  const right = answers.filter((a) => a.correct).length;
  if (right === 0) out.push("Mark the correct answer");
  if (q.type !== "multi_choice" && right > 1) out.push("Only one answer can be correct (or choose “several right answers”)");
  return out;
}

/** Saves a question and replaces its answers. */
export async function saveQuestion(db: Db, activityId: string, q: QuestionInput, id?: string) {
  const problems = checkQuestion(q);
  if (problems.length) throw new AdminError(problems.join(". ") + ".");
  let qid = id;
  const row = { type: q.type, difficulty: q.difficulty, prompt_image_asset_id: q.imageAssetId, prompt_audio_asset_id: q.audioAssetId };
  if (qid) {
    const old = must(await db.from("questions").select("prompt").eq("id", qid).single());
    mustOne(await db.from("questions").update({ ...row, prompt: withEn(old.prompt, q.prompt) }).eq("id", qid).select("id"));
    must(await db.from("answers").delete().eq("question_id", qid));
  } else {
    const last = must(await db.from("questions").select("position").eq("activity_id", activityId).order("position", { ascending: false }).limit(1));
    qid = must(await db.from("questions").insert({ ...row, activity_id: activityId, position: last.length ? last[0].position + 1 : 0, prompt: { en: q.prompt } }).select("id").single()).id as string;
  }
  const answers = q.answers.filter((a) => a.text.trim());
  must(await db.from("answers").insert(answers.map((a, i) => ({ question_id: qid, position: i, content: { en: a.text.trim() }, is_correct: a.correct }))));
  return { id: qid };
}
export async function deleteQuestion(db: Db, id: string) { mustOne(await db.from("questions").delete().eq("id", id).select("id")); }
