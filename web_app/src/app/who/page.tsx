import Link from "next/link";
import { BuddyArt, buddyIndex } from "@/components/buddy-art";
import type { Metadata } from "next";
import { ParentIcon } from "@/components/icons";
import { PendingButton } from "@/components/pending-button";
import { listChildren, requireFamily } from "@/lib/session";
import { chooseChild } from "../zone-actions";

export const metadata: Metadata = { title: "Who's playing?" };

export default async function Who() {
  const { db } = await requireFamily("/who");
  const kids = await listChildren(db);
  return (
    <main className="kids flex min-h-screen flex-col items-center px-s5 py-s9">
      <h1 className="font-display text-kids-display">Who&apos;s playing?</h1>
      {kids.length === 0 ? (
        <p className="mt-s6 text-kids-body">No children yet. <Link className="underline" href="/gate?next=/parents/children/new">A grown-up can add one.</Link></p>
      ) : (
        <ul className="mt-s8 grid w-full max-w-ui-content-max grid-cols-2 gap-s5 sm:grid-cols-3 lg:grid-cols-4">
          {kids.map((k) => (
            <li key={k.id}>
              <form action={chooseChild.bind(null, k.id)}>
                <PendingButton aria-label={`${k.nickname} is playing`} className="flex w-full flex-col items-center gap-s3 rounded-xl bg-kids-surface p-s5 shadow-kid-raised transition-transform hover:-translate-y-s1 active:shadow-kid-pressed">
                  <span className="size-kids-buddy-tile overflow-hidden rounded-pill bg-kids-me-soft p-s3"><BuddyArt index={buddyIndex(k.avatarKey)} /></span>
                  <span className="max-w-full truncate font-display text-kids-title">{k.nickname}</span>
                </PendingButton>
              </form>
            </li>
          ))}
        </ul>
      )}
      <Link href="/gate?next=/parents" className="mt-s9 flex min-h-tap-kids-secondary items-center gap-s2 rounded-lg px-s4 font-bold text-kids-ink-muted hover:bg-kids-bg-alt"><ParentIcon />Grown-ups</Link>
    </main>
  );
}
