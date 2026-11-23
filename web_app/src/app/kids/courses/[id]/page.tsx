import Link from "next/link";
import { notFound } from "next/navigation";
import { CheckIcon, LockIcon, StarIcon } from "@/components/icons";
import { ProgressBar } from "@/components/kids";
import { courseTree } from "@/lib/data/catalog";
import { kidContext } from "@/lib/kid";
import { courseFraction, lessonStates } from "@/lib/rules";

const LOOK = { completed: "bg-kids-success-fill", in_progress: "bg-kids-learn-fill", available: "bg-kids-learn-soft", locked: "bg-kids-line text-kids-ink-muted" };
const SAY = { completed: "done", in_progress: "started", available: "ready", locked: "locked" };

/** The course map: islands (lessons) in a winding line. Open ones are links; locked ones say why. */
export default async function Course({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { db, progress } = await kidContext();
  const tree = await courseTree(db, id);
  if (!tree) notFound();
  const states = lessonStates(tree, progress.doneSteps);
  return (
    <div className="flex flex-col gap-s6">
      <div>
        <Link href="/kids/learn" className="font-bold underline">Learn</Link>
        <h1 className="mt-s2 font-display text-kids-title">{tree.course.title}</h1>
        <p className="text-kids-body text-kids-ink-muted">{tree.course.description}</p>
        <div className="mt-s3 max-w-ui-form-w"><ProgressBar value={courseFraction(tree, progress.doneSteps)} label="Course progress" /></div>
      </div>
      <ol className="flex flex-col gap-s5" aria-label="Lessons">
        {tree.lessons.map((l, i) => {
          const st = states[i];
          const body = (
            <span className={`flex items-center gap-s4 rounded-xl p-s4 shadow-kid-raised ${i % 2 ? "md:ml-kids-node" : ""} ${st === "locked" ? "bg-kids-bg-alt" : "bg-kids-surface"}`}>
              <span className={`flex size-kids-node shrink-0 items-center justify-center rounded-pill font-display text-kids-title ${LOOK[st]}`}>
                {st === "completed" ? <CheckIcon className="size-icon-kids" /> : st === "locked" ? <LockIcon className="size-icon-kids" /> : i + 1}
              </span>
              <span className="flex min-w-0 flex-col gap-s1">
                <span className="font-display text-kids-label">{l.title}</span>
                <span className="text-kids-caption text-kids-ink-muted">{l.steps.length} activities{l.estimatedMinutes ? ` · about ${l.estimatedMinutes} min` : ""}{l.hasPrize ? " · a prize at the end" : ""}</span>
                {st === "locked" && <span className="text-kids-caption">Finish the lessons before this one first.</span>}
              </span>
              {l.hasPrize && <span className="ml-auto text-kids-star"><StarIcon /></span>}
            </span>
          );
          return (
            <li key={l.id} aria-label={`Lesson ${i + 1}: ${l.title}, ${SAY[st]}`}>
              {st === "locked" ? body : <Link href={`/kids/courses/${id}/lessons/${l.id}`} className="block">{body}</Link>}
            </li>
          );
        })}
      </ol>
    </div>
  );
}
