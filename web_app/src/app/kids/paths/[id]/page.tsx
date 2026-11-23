import Link from "next/link";
import { notFound } from "next/navigation";
import { CheckIcon } from "@/components/icons";
import { kidContext } from "@/lib/kid";

/** A learning path: its courses in order, each marked started or finished. */
export default async function PathPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { catalog, progress } = await kidContext();
  const path = catalog.paths.find((p) => p.id === id);
  if (!path) notFound();
  const courses = path.courseIds.map((cid) => catalog.courses.find((c) => c.id === cid)).filter((c) => !!c);
  return (
    <div className="flex flex-col gap-s6">
      <div><Link href="/kids/learn" className="font-bold underline">Learn</Link><h1 className="mt-s2 font-display text-kids-title">{path.title}</h1><p className="text-kids-body text-kids-ink-muted">{path.description}</p></div>
      <ol className="flex flex-col gap-s4">
        {courses.map((c, i) => {
          const st = progress.enrolled.get(c.id);
          return (
            <li key={c.id}>
              <Link href={`/kids/courses/${c.id}`} className="flex items-center gap-s4 rounded-xl bg-kids-surface p-s5 shadow-kid-raised">
                <span className={`flex size-tap-kids shrink-0 items-center justify-center rounded-pill font-display text-kids-heading ${st === "completed" ? "bg-kids-success-fill" : "bg-kids-learn-soft"}`}>{st === "completed" ? <CheckIcon className="size-icon-kids" title="Finished" /> : i + 1}</span>
                <span className="flex flex-col"><span className="font-display text-kids-label">{c.title}</span><span className="text-kids-caption text-kids-ink-muted">{c.lessonCount} lessons{st === "active" ? " · started" : ""}</span></span>
              </Link>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
