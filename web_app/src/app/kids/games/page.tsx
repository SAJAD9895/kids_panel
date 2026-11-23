import type { Metadata } from "next";
import { ActivityCard, Shelf } from "@/components/kids";
import { kidContext } from "@/lib/kid";

export const metadata: Metadata = { title: "Games" };

export default async function Games() {
  const { visible, locked, catalog, progress } = await kidContext();
  const done = new Set(progress.played.filter((p) => p.status === "completed").map((p) => p.activityId));
  const games = visible.filter((a) => a.type === "game" || a.type === "quiz");
  return (
    <div className="flex flex-col gap-s8">
      <h1 className="font-display text-kids-title">Games</h1>
      {catalog.subjects.map((s) => {
        const list = games.filter((g) => g.subjectId === s.id);
        return list.length ? <Shelf key={s.id} title={s.name}>{list.map((a) => <ActivityCard key={a.id} a={a} locked={locked(a)} done={done.has(a.id)} />)}</Shelf> : null;
      })}
      {games.length === 0 && <p className="text-kids-body">No games for you yet.</p>}
    </div>
  );
}
