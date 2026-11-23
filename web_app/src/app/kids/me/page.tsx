import type { Metadata } from "next";
import Link from "next/link";
import { BuddyPicker } from "@/components/buddy-picker";
import { StarIcon } from "@/components/icons";
import { listBuddies } from "@/lib/data/family";
import { ageYears } from "@/lib/format";
import { kidContext } from "@/lib/kid";
import { changeBuddy } from "./actions";
import { PendingButton } from "@/components/pending-button";

export const metadata: Metadata = { title: "Me" };

export default async function Me() {
  const { db, child, progress } = await kidContext();
  const buddies = await listBuddies(db);
  return (
    <div className="flex flex-col gap-s8">
      <section className="flex flex-col gap-s2">
        <h1 className="font-display text-kids-title">{child.nickname}</h1>
        <p className="text-kids-body text-kids-ink-muted">{ageYears(child.birthYearMonth)} years old</p>
      </section>
      <Link href="/kids/me/rewards" className="flex items-center justify-between gap-s4 rounded-xl bg-kids-me-soft p-s6 shadow-kid-raised">
        <span className="flex flex-col"><span className="font-display text-kids-heading">My stars and badges</span><span className="text-kids-body text-kids-ink-muted">See what you&apos;ve collected</span></span>
        <span className="flex items-center gap-s2 font-display text-kids-title"><span className="text-kids-star"><StarIcon className="size-icon-kids" /></span>{progress.stars}</span>
      </Link>
      <form action={changeBuddy} className="flex max-w-ui-form-w flex-col gap-s4 rounded-xl bg-kids-surface p-s6 shadow-kid-raised">
        <BuddyPicker buddies={buddies} initial={child.avatarId} label="My buddy" />
        <PendingButton pendingLabel="Saving…" className="min-h-tap-kids self-start rounded-xl bg-kids-me-fill px-s6 font-display text-kids-label shadow-kid-raised">Choose this buddy</PendingButton>
      </form>
      <Link href="/who" className="self-start font-bold underline">Someone else is playing</Link>
    </div>
  );
}
