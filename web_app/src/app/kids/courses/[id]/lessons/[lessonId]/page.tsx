import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { CheckIcon, LockIcon, PlayIcon } from "@/components/icons";
import { KIND_WORD, TONE, toneOf } from "@/components/kids";
import { courseTree } from "@/lib/data/catalog";
import { hrefFor, kidContext } from "@/lib/kid";
import { lessonStates, stepStates } from "@/lib/rules";

/** One lesson: its steps in order. The next step to do is big; done steps can be replayed. */
export default async function LessonPage({ params }: { params: Promise<{ id: string; lessonId: string }> }) {
  const { id, lessonId } = await params;
  const { db, progress } = await kidContext();
  const tree = await courseTree(db, id);
  if (!tree) notFound();
  const i = tree.lessons.findIndex((l) => l.id === lessonId);
  if (i < 0) notFound();
  const lessonState = lessonStates(tree, progress.doneSteps)[i];
  if (lessonState === "locked") redirect(`/kids/courses/${id}`);
  const lesson = tree.lessons[i];
  const steps = stepStates(lesson, lessonState, progress.doneSteps);
  const nextIdx = steps.findIndex((s, j) => s === "available" && lesson.steps[j].required);
  const next = tree.lessons[i + 1];
  return (
    <div className="flex flex-col gap-s6">
      <div><Link href={`/kids/courses/${id}`} className="font-bold underline">{tree.course.title}</Link><h1 className="mt-s2 font-display text-kids-title">{lesson.title}</h1></div>
      <ol className="grid gap-s4 md:grid-cols-2">
        {lesson.steps.map((s, j) => {
          const st = steps[j];
          const tone = TONE[toneOf(s.activity)];
          const href = `${hrefFor(s.activity)}?step=${s.id}&course=${id}&lesson=${lessonId}`;
          const inner = (
            <span className={`flex items-center gap-s4 rounded-xl p-s4 shadow-kid-raised ${st === "locked" ? "bg-kids-bg-alt text-kids-ink-muted" : "bg-kids-surface"} ${j === nextIdx ? "ring-4 ring-kids-focus" : ""}`}>
              <span className={`flex size-tap-kids shrink-0 items-center justify-center rounded-pill ${st === "completed" ? "bg-kids-success-fill" : st === "locked" ? "bg-kids-line" : tone.fill}`}>
                {st === "completed" ? <CheckIcon /> : st === "locked" ? <LockIcon /> : <PlayIcon />}
              </span>
              <span className="flex flex-col"><span className={`text-kids-caption font-bold ${tone.ink}`}>{KIND_WORD[s.activity.type]}{s.required ? "" : " · extra"}</span><span className="font-display text-kids-label">{s.activity.title}</span></span>
            </span>
          );
          return <li key={s.id}>{st === "locked" ? inner : <Link href={href} className="block">{inner}</Link>}</li>;
        })}
      </ol>
      {lessonState === "completed" && next && <Link href={`/kids/courses/${id}/lessons/${next.id}`} className="self-start rounded-xl bg-kids-learn-fill px-s6 py-s4 font-display text-kids-label shadow-kid-raised">Next lesson: {next.title}</Link>}
    </div>
  );
}
