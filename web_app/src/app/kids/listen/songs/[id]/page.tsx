import Link from "next/link";
import { notFound } from "next/navigation";
import { AudioPlayer } from "@/components/media/audio-player";
import { MediaRefused } from "@/components/media/refused";
import { getActivity } from "@/lib/data/catalog";
import { launch } from "@/lib/data/launch";
import { kidContext } from "@/lib/kid";

export default async function Song({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ step?: string; course?: string; lesson?: string }> }) {
  const [{ id }, sp] = await Promise.all([params, searchParams]);
  const { db, child } = await kidContext();
  const a = await getActivity(db, id);
  if (!a || !["song", "audio_story"].includes(a.activity.type)) notFound();
  const l = await launch(child.id, id, sp.step ? "course" : "feed");
  const back = sp.course && sp.lesson ? { href: `/kids/courses/${sp.course}/lessons/${sp.lesson}`, label: "Back to the lesson" } : { href: "/kids/listen", label: "More to listen to" };
  return (
    <div className="mx-auto flex max-w-ui-content-max flex-col gap-s5">
      <Link href={back.href} className="self-start font-bold underline">{back.href === "/kids/listen" ? "Listen" : "Back to the lesson"}</Link>
      <h1 className="font-display text-kids-title">{a.activity.title}</h1>
      {l.ok ? <AudioPlayer childId={child.id} activityId={id} title={a.activity.title} contentVersion={l.launch.contentVersion} stepId={sp.step} files={l.launch.files} resume={l.launch.resume} cover={a.activity.thumb} done={back} />
        : <MediaRefused type={l.type} message={l.message} back={back} />}
    </div>
  );
}
