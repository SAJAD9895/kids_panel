import type { Metadata } from "next";
import Link from "next/link";
import { ProgressBar } from "@/components/kids";
import { CollectionShelves } from "@/components/shelves";
import { kidContext } from "@/lib/kid";

export const metadata: Metadata = { title: "Learn" };
const STAGE_MONTHS: Record<string, [number, number]> = { toddler: [12, 36], preschool: [36, 60], kindergarten: [60, 84], grade1: [72, 96], grade2: [84, 108] };

export default async function Learn() {
  const { catalog, months, progress } = await kidContext();
  if (!progress.switches.learn) return <p className="text-kids-body">A grown-up switched Learn off for now.</p>;
  const fits = (stage: string) => { const r = STAGE_MONTHS[stage]; return !r || (months >= r[0] - 6 && months <= r[1] + 6); };
  const paths = catalog.paths.filter((p) => months >= p.ageMin && months <= p.ageMax);
  const courses = catalog.courses.filter((c) => fits(c.stage));
  return (
    <div className="flex flex-col gap-s8">
      <div className="flex flex-wrap items-baseline justify-between gap-s4">
        <h1 className="font-display text-kids-title">Learn</h1>
        <Link href="/kids/subjects" className="text-kids-label font-bold underline">All subjects</Link>
      </div>
      {paths.length > 0 && (
        <section aria-label="Learning paths" className="flex flex-col gap-s3">
          <h2 className="font-display text-kids-heading">Learning paths</h2>
          <div className="grid gap-s4 md:grid-cols-2">
            {paths.map((p) => (
              <Link key={p.id} href={`/kids/paths/${p.id}`} className="flex flex-col gap-s2 rounded-xl bg-kids-learn-soft p-s5 shadow-kid-raised">
                <span className="font-display text-kids-heading">{p.title}</span>
                <span className="text-kids-body text-kids-ink-muted">{p.description}</span>
                <span className="text-kids-caption font-bold text-kids-learn-ink">{p.courseIds.length} courses</span>
              </Link>
            ))}
          </div>
        </section>
      )}
      <section aria-label="Courses" className="flex flex-col gap-s3">
        <h2 className="font-display text-kids-heading">Courses</h2>
        {courses.length === 0 ? <p className="text-kids-body">No courses for you yet.</p> : (
          <ul className="grid gap-s4 sm:grid-cols-2 xl:grid-cols-3">
            {courses.map((c) => (
              <li key={c.id}>
                <Link href={`/kids/courses/${c.id}`} className="flex h-full flex-col gap-s3 rounded-xl bg-kids-surface p-s5 shadow-kid-raised">
                  <span className="font-display text-kids-label">{c.title}</span>
                  <span className="line-clamp-2 text-kids-body text-kids-ink-muted">{c.description}</span>
                  <span className="mt-auto text-kids-caption font-bold text-kids-learn-ink">{c.lessonCount} lessons{progress.enrolled.has(c.id) ? " · started" : ""}</span>
                  {progress.enrolled.get(c.id) === "completed" && <ProgressBar value={1} label="Finished" />}
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>
      <CollectionShelves surface="learn" />
    </div>
  );
}
