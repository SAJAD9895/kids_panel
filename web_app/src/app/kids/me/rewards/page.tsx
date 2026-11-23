/* eslint-disable @next/next/no-img-element -- badge art */
import type { Metadata } from "next";
import Link from "next/link";
import { LockIcon, StarIcon } from "@/components/icons";
import { ProgressBar } from "@/components/kids";
import { rewardsOf } from "@/lib/data/rewards";
import { kidContext } from "@/lib/kid";

export const metadata: Metadata = { title: "My rewards" };

export default async function MyRewards() {
  const { child } = await kidContext();
  const r = await rewardsOf(child.id);
  const earned = r.badges.filter((b) => b.earnedAt);
  return (
    <div className="flex flex-col gap-s8">
      <div><Link href="/kids/me" className="font-bold underline">Me</Link><h1 className="mt-s2 font-display text-kids-title">My rewards</h1></div>
      <section className="grid gap-s4 md:grid-cols-3">
        <div className="flex flex-col items-center gap-s2 rounded-xl bg-kids-surface p-s6 shadow-kid-raised">
          <span className="text-kids-star"><StarIcon className="size-kids-node" /></span>
          <span className="font-display text-kids-display">{r.balance}</span><span className="text-kids-body">stars</span>
        </div>
        <div className="flex flex-col gap-s3 rounded-xl bg-kids-surface p-s6 shadow-kid-raised">
          <h2 className="font-display text-kids-heading">Today</h2>
          {r.goals.enabled ? <><ProgressBar value={r.day.progress / Math.max(1, r.day.target)} tone="me" label={`Today: ${r.day.progress} of ${r.day.target}`} /><p className="text-kids-body">{r.day.progress} of {r.day.target} done{r.day.completedAt ? " — goal reached!" : ""}</p></> : <p className="text-kids-body">Play anything you like.</p>}
        </div>
        <div className="flex flex-col gap-s3 rounded-xl bg-kids-surface p-s6 shadow-kid-raised">
          <h2 className="font-display text-kids-heading">This week</h2>
          {r.goals.enabled && <ProgressBar value={r.week.progress / Math.max(1, r.week.target)} tone="learn" label={`This week: ${r.week.progress} of ${r.week.target} days`} />}
          <p className="text-kids-body">{r.week.progress} learning {r.week.progress === 1 ? "day" : "days"}. Streak: {r.streak.current} {r.streak.current === 1 ? "day" : "days"}.</p>
        </div>
      </section>
      <section className="flex flex-col gap-s4" aria-label="Badges">
        <h2 className="font-display text-kids-heading">Badges ({earned.length} of {r.badges.length})</h2>
        <ul className="grid grid-cols-2 gap-s4 sm:grid-cols-3 lg:grid-cols-4">
          {r.badges.map((b) => (
            <li key={b.key} className={`flex flex-col items-center gap-s2 rounded-xl p-s4 text-center shadow-kid-raised ${b.earnedAt ? "bg-kids-surface" : "bg-kids-bg-alt"}`}>
              <span className="relative size-kids-node">
                {b.art ? <img src={b.art} alt="" loading="lazy" className={`size-full object-contain ${b.earnedAt ? "" : "opacity-30 grayscale"}`} /> : null}
                {!b.earnedAt && <span className="absolute inset-0 flex items-center justify-center text-kids-ink-muted"><LockIcon className="size-icon-kids" /></span>}
              </span>
              <span className="font-display text-kids-label">{b.title}</span>
              <span className="text-kids-caption text-kids-ink-muted">{b.earnedAt ? b.description : b.howToEarn}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
