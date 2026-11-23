import { notFound } from "next/navigation";
import { ActivityCard, Shelf } from "@/components/kids";
import { kidContext } from "@/lib/kid";

const ORDER = ["game", "quiz", "video", "song", "story", "audio_story", "together", "printable"];
const TITLE: Record<string, string> = { game: "Games", quiz: "Quizzes", video: "Videos", song: "Songs", story: "Stories", audio_story: "Audio stories", together: "Together", printable: "To print" };

/** A subject (letters, numbers…) or a category (`category-<key>`): everything in it, by kind. */
export default async function Subject({ params }: { params: Promise<{ key: string }> }) {
  const { key } = await params;
  const { catalog, visible, locked } = await kidContext();
  const cat = key.startsWith("category-") ? catalog.categories.find((c) => `category-${c.key}` === key) : null;
  const subj = cat ? null : catalog.subjects.find((s) => s.key === key);
  if (!cat && !subj) notFound();
  const items = visible.filter((a) => (cat ? a.categoryId === cat.id : a.subjectId === subj!.id));
  return (
    <div className="flex flex-col gap-s8">
      <h1 className="font-display text-kids-title">{cat?.name ?? subj!.name}</h1>
      {items.length === 0 && <p className="text-kids-body">Nothing here for you yet.</p>}
      {ORDER.map((type) => {
        const list = items.filter((a) => a.type === type);
        return list.length ? <Shelf key={type} title={TITLE[type]}>{list.map((a) => <ActivityCard key={a.id} a={a} locked={locked(a)} />)}</Shelf> : null;
      })}
    </div>
  );
}
