import { notFound } from "next/navigation";
import { MediaRefused } from "@/components/media/refused";
import { Player } from "@/components/play/player";
import { sourceFromRow, type QuestionRow } from "@/lib/engine";
import { kidContext } from "@/lib/kid";
import { t } from "@/lib/format";

/** Games and quizzes. The row is read exactly as the app reads it (play_data.dart), under RLS
 * (published only); the parent's switches never block games, and Plus is checked here as the
 * server's launch would (games and quizzes have no media to sign). */
export default async function Play({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ step?: string; course?: string; lesson?: string }> }) {
  const [{ id }, sp] = await Promise.all([params, searchParams]);
  const { db, child, months, progress } = await kidContext();
  const { data: row, error } = await db.from("activities")
    .select("id, slug, type, title, description, subject_id, age_min_months, age_max_months, estimated_seconds, plus_only, players, difficulty, content_version, games(config), questions(id, position, type, prompt, answers(id, position, content, is_correct, match_key, correct_order))")
    .eq("id", id).eq("status", "published").maybeSingle();
  if (error) throw new Error(error.message);
  if (!row || !["game", "quiz"].includes(row.type as string)) notFound();
  const back = sp.course && sp.lesson ? { href: `/kids/courses/${sp.course}/lessons/${sp.lesson}`, label: "Back to the lesson" } : { href: row.type === "quiz" ? "/kids/learn" : "/kids/games", label: "More games" };
  if (row.plus_only && !progress.hasPlus) return <MediaRefused type="NEEDS_PLUS" message="This one is part of Plus. Ask a grown-up." back={back} />;
  if (months < (row.age_min_months as number) || months > (row.age_max_months as number)) return <MediaRefused type="AGE_NOT_SUITABLE" message="This one is for a different age." back={back} />;
  const questions = [...((row.questions as unknown as QuestionRow[]) ?? [])].sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
  const source = sourceFromRow({ id: row.id as string, games: row.games as { config?: unknown } | null, questions, content_version: row.content_version as number, difficulty: row.difficulty as number });
  return <Player source={JSON.parse(JSON.stringify(source))} childId={child.id} ageMonths={months} stepId={sp.step ?? null} title={t(row.title)} back={back} />;
}
