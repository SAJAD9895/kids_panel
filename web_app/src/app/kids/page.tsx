import type { Metadata } from "next";
import Link from "next/link";
import { ActivityCard, ProgressBar, Shelf } from "@/components/kids";
import { CollectionShelves } from "@/components/shelves";
import { StarIcon } from "@/components/icons";
import { rewardsOf } from "@/lib/data/rewards";
import { kidContext } from "@/lib/kid";
import { resumeFraction, worthResuming } from "@/lib/rules";

export const metadata: Metadata = { title: "Home" };

export default async function KidsHome() {
  const { child, progress, visible, locked, catalog } = await kidContext();
  const resume = visible.filter((a) => worthResuming(progress.resume.get(a.id)));
  const startedCourses = catalog.courses.filter((c) => progress.enrolled.get(c.id) === "active");
  const r = await rewardsOf(child.id); // the day's goal, counted by the server as in the app
  return (
    <div className="flex flex-col gap-s8">
      <section className="flex flex-col gap-s4 rounded-xl bg-kids-me-soft p-s6 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="font-display text-kids-title">Hi {child.nickname}!</h1>
          <p className="text-kids-body text-kids-ink-muted">What shall we do today?</p>
        </div>
        <div className="flex min-w-0 flex-col gap-s2 md:w-ui-sidebar-w">
          <p className="flex items-center gap-s2 text-kids-label font-bold"><span className="text-kids-star"><StarIcon /></span>{progress.todayStars} {progress.todayStars === 1 ? "star" : "stars"} today</p>
          {r.goals.enabled && <><ProgressBar value={r.day.progress / Math.max(1, r.day.target)} tone="me" label={`Today's goal: ${r.day.progress} of ${r.day.target} activities`} />
            <p className="text-kids-caption text-kids-ink-muted">{r.day.completedAt ? "Today's goal done!" : `${r.day.progress} of ${r.day.target} activities for today's goal`}</p></>}
        </div>
      </section>
      {(resume.length > 0 || startedCourses.length > 0) && (
        <Shelf title="Keep going">
          {[
            ...resume.map((a) => <ActivityCard key={a.id} a={a} locked={locked(a)} progress={resumeFraction(progress.resume.get(a.id)!)} />),
            ...startedCourses.map((c) => (
              <Link key={c.id} href={`/kids/courses/${c.id}`} className="flex w-kids-card-w shrink-0 flex-col justify-end gap-s2 rounded-xl bg-kids-learn-soft p-s4 shadow-kid-raised">
                <span className="text-kids-caption font-bold text-kids-learn-ink">Course</span>
                <span className="font-display text-kids-label">{c.title}</span>
              </Link>
            )),
          ]}
        </Shelf>
      )}
      <CollectionShelves surface="home" />
    </div>
  );
}
