import type { Metadata } from "next";
import { ActivityCard, Shelf } from "@/components/kids";
import { CollectionShelves } from "@/components/shelves";
import { kidContext } from "@/lib/kid";
import { resumeFraction, worthResuming } from "@/lib/rules";

export const metadata: Metadata = { title: "Listen" };

export default async function Listen() {
  const { visible, locked, progress } = await kidContext();
  if (!progress.switches.listen) return <p className="text-kids-body">A grown-up switched songs and stories off.</p>;
  const media = visible.filter((a) => ["song", "story", "audio_story"].includes(a.type));
  const keep = media.filter((a) => worthResuming(progress.resume.get(a.id)));
  const card = (a: (typeof media)[number]) => <ActivityCard key={a.id} a={a} locked={locked(a)} progress={progress.resume.get(a.id) ? resumeFraction(progress.resume.get(a.id)!) : undefined} />;
  return (
    <div className="flex flex-col gap-s8">
      <h1 className="font-display text-kids-title">Listen and read</h1>
      {keep.length > 0 && <Shelf title="Keep listening and reading">{keep.map(card)}</Shelf>}
      <CollectionShelves surface="listen" />
      <Shelf title="Songs" empty="No songs for you yet.">{media.filter((a) => a.type === "song").map(card)}</Shelf>
      <Shelf title="Stories" empty="No stories for you yet.">{media.filter((a) => a.type === "story" || a.type === "audio_story").map(card)}</Shelf>
    </div>
  );
}
