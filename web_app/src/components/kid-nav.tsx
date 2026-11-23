"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { GamesIcon, HomeIcon, LearnIcon, ListenIcon, MeIcon, WatchIcon } from "./icons";
import { TONE, type Tone } from "./kids";

const ITEMS: { href: string; label: string; tone: Tone; Icon: typeof HomeIcon; key: string }[] = [
  { href: "/kids", label: "Home", tone: "me", Icon: HomeIcon, key: "home" },
  { href: "/kids/learn", label: "Learn", tone: "learn", Icon: LearnIcon, key: "learn" },
  { href: "/kids/games", label: "Games", tone: "play", Icon: GamesIcon, key: "games" },
  { href: "/kids/watch", label: "Watch", tone: "watch", Icon: WatchIcon, key: "watch" },
  { href: "/kids/listen", label: "Listen", tone: "listen", Icon: ListenIcon, key: "listen" },
  { href: "/kids/me", label: "Me", tone: "me", Icon: MeIcon, key: "me" },
];

/** The child's sections: a rail on the left on wide screens, a bar at the bottom on phones.
 * Sections a grown-up switched off aren't shown. */
export function KidNav({ hidden }: { hidden: string[] }) {
  const path = usePathname();
  const active = (href: string) => (href === "/kids" ? path === "/kids" : path.startsWith(href));
  const items = ITEMS.filter((i) => !hidden.includes(i.key));
  return (
    <nav aria-label="Sections" className="fixed inset-x-0 bottom-0 z-20 border-t border-kids-line bg-kids-surface lg:inset-y-0 lg:left-0 lg:right-auto lg:w-kids-rail-w lg:border-r lg:border-t-0 lg:pt-kids-header-h">
      <ul className="flex justify-around gap-s1 px-s1 py-s1 lg:flex-col lg:justify-start lg:gap-s3 lg:px-s2 lg:py-s4">
        {items.map(({ href, label, tone, Icon }) => (
          <li key={href} className="flex-1 lg:flex-none">
            <Link href={href} aria-current={active(href) ? "page" : undefined}
              className={`flex min-h-tap-kids-secondary flex-col items-center justify-center gap-s1 rounded-lg px-s1 text-kids-caption font-bold lg:min-h-tap-kids-xl ${active(href) ? `${TONE[tone].fill} text-kids-ink` : "text-kids-ink-muted hover:bg-kids-bg-alt"}`}>
              <Icon className="size-icon-kids" />{label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
