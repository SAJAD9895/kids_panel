import type { Activity } from "@/lib/data/catalog";
import { kidContext } from "@/lib/kid";
import { resumeFraction } from "@/lib/rules";
import { ActivityCard, Shelf } from "./kids";

/** The published collections for one section, each limited to what this child may see. */
export async function CollectionShelves({ surface, only }: { surface: string; only?: (a: Activity) => boolean }) {
  const { catalog, visible, locked, progress } = await kidContext();
  const ok = new Set(visible.filter(only ?? (() => true)).map((a) => a.id));
  const byId = new Map(visible.map((a) => [a.id, a]));
  const done = new Set(progress.played.filter((p) => p.status === "completed").map((p) => p.activityId));
  return (
    <>
      {catalog.collections.filter((c) => c.surface === surface).map((c) => {
        const items = c.activityIds.filter((id) => ok.has(id)).map((id) => byId.get(id)!);
        if (!items.length) return null;
        return (
          <Shelf key={c.id} title={c.title}>
            {items.map((a) => <ActivityCard key={a.id} a={a} locked={locked(a)} done={done.has(a.id)} progress={progress.resume.get(a.id) ? resumeFraction(progress.resume.get(a.id)!) : undefined} />)}
          </Shelf>
        );
      })}
    </>
  );
}
