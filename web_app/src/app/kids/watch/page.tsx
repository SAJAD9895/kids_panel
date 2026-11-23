import type { Metadata } from "next";
import { ActivityCard, Shelf } from "@/components/kids";
import { CollectionShelves } from "@/components/shelves";
import { kidContext } from "@/lib/kid";
import { resumeFraction, worthResuming } from "@/lib/rules";

export const metadata: Metadata = { title: "Watch" };

export default async function Watch() {
  const { visible, locked, progress } = await kidContext();
  if (!progress.switches.watch) return <p className="text-kids-body">A grown-up switched videos off.</p>;
  const videos = visible.filter((a) => a.type === "video");
  const keep = videos.filter((a) => worthResuming(progress.resume.get(a.id)));
  return (
    <div className="flex flex-col gap-s8">
      <h1 className="font-display text-kids-title">Watch</h1>
      {keep.length > 0 && <Shelf title="Keep watching">{keep.map((a) => <ActivityCard key={a.id} a={a} locked={locked(a)} progress={resumeFraction(progress.resume.get(a.id)!)} />)}</Shelf>}
      <CollectionShelves surface="watch" only={(a) => a.type === "video"} />
      <Shelf title="All videos" empty="No videos for you yet.">{videos.map((a) => <ActivityCard key={a.id} a={a} locked={locked(a)} />)}</Shelf>
    </div>
  );
}
