import Link from "next/link";
import { BuddyArt, buddyIndex } from "@/components/buddy-art";
import { KidNav } from "@/components/kid-nav";
import { ParentIcon } from "@/components/icons";
import { Stars } from "@/components/kids";
import { kidContext } from "@/lib/kid";

export default async function KidsLayout({ children }: { children: React.ReactNode }) {
  const { child, progress } = await kidContext();
  const sw = progress.switches;
  const hidden = [!sw.learn && "learn", !sw.watch && "watch", !sw.listen && "listen"].filter(Boolean) as string[];
  return (
    <div className="kids min-h-screen">
      <header className="sticky top-0 z-30 flex h-kids-header-h items-center justify-between gap-s3 border-b border-kids-line bg-kids-bg/95 px-s4 backdrop-blur lg:px-s6">
        <Link href="/kids/me" className="flex min-w-0 items-center gap-s3" aria-label={`${child.nickname}: my page`}>
          <span className="size-tap-kids shrink-0 overflow-hidden rounded-pill bg-kids-me-soft p-s1"><BuddyArt index={buddyIndex(child.avatarKey)} /></span>
          <span className="truncate font-display text-kids-heading">{child.nickname}</span>
        </Link>
        <div className="flex items-center gap-s3">
          <Stars n={progress.stars} />
          <Link href="/gate?next=/parents" className="flex min-h-tap-kids-secondary items-center gap-s2 rounded-lg px-s3 text-kids-caption font-bold text-kids-ink-muted hover:bg-kids-bg-alt">
            <ParentIcon /><span className="hidden sm:inline">Grown-ups</span><span className="sr-only sm:hidden">Grown-ups</span>
          </Link>
        </div>
      </header>
      <KidNav hidden={hidden} />
      <main className="mx-auto max-w-ui-content-max px-s4 pb-s12 pt-s5 lg:ml-kids-rail-w lg:px-s8 lg:pb-s10 xl:mx-auto xl:pl-kids-rail-w">{children}</main>
    </div>
  );
}
