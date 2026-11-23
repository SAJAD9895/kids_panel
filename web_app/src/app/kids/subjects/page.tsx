import type { Metadata } from "next";
import Link from "next/link";
import { TONE, type Tone } from "@/components/kids";
import { kidContext } from "@/lib/kid";

export const metadata: Metadata = { title: "Subjects" };
const TONES: Tone[] = ["learn", "play", "watch", "listen", "me"];

export default async function Subjects() {
  const { catalog, visible } = await kidContext();
  return (
    <div className="flex flex-col gap-s6">
      <h1 className="font-display text-kids-title">Explore</h1>
      <ul className="grid grid-cols-2 gap-s4 md:grid-cols-3 xl:grid-cols-4">
        {catalog.subjects.map((s, i) => {
          const n = visible.filter((a) => a.subjectId === s.id).length;
          const tone = TONE[TONES[i % TONES.length]];
          return (
            <li key={s.id}>
              <Link href={`/kids/subjects/${s.key}`} className={`flex min-h-kids-node flex-col justify-between gap-s2 rounded-xl p-s5 shadow-kid-raised ${tone.soft}`}>
                <span className="font-display text-kids-heading">{s.name}</span>
                <span className={`text-kids-caption font-bold ${tone.ink}`}>{n} to try</span>
              </Link>
            </li>
          );
        })}
      </ul>
      <h2 className="font-display text-kids-heading">Categories</h2>
      <ul className="flex flex-wrap gap-s3">
        {catalog.categories.map((c) => (
          <li key={c.id}><Link href={`/kids/subjects/category-${c.key}`} className="inline-flex min-h-tap-kids-secondary items-center rounded-pill bg-kids-surface px-s5 font-bold shadow-kid-raised">{c.name}</Link></li>
        ))}
      </ul>
    </div>
  );
}
