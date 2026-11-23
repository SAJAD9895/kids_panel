// The 12 buddies, drawn in SVG with the design tokens: the same shapes as the app
// (kids_app/lib/core/art/characters.dart, from docs/design/mockups/lib.js). Original art.
const V = (n: string) => `var(--color-${n})`;
const BODY = ["play", "learn", "watch", "listen", "me", "play", "learn", "watch", "listen", "me", "learn", "play"];
const TOP = ["ears", "antenna", "leaf", "horns", "tuft", "ears", "leaf", "antenna", "tuft", "horns", "ears", "leaf"];
export const BUDDY_NAMES = ["Bun", "Zippy", "Sprout", "Rumble", "Fluff", "Momo", "Leafy", "Beepo", "Tufty", "Dino", "Pebble", "Maple"];
/** avatars.key `buddy-01` → art 0, as in the app. */
export const buddyIndex = (key: string | null | undefined) => {
  const n = Number(/(\d+)$/.exec(key ?? "")?.[1] ?? 1);
  return (((n - 1) % 12) + 12) % 12;
};

function Eyes({ cx, cy, gap, r, happy }: { cx: number; cy: number; gap: number; r: number; happy: boolean }) {
  const L = cx - gap, R = cx + gap;
  if (happy) return <path d={`M${L - r} ${cy} q${r} ${-r * 1.4} ${r * 2} 0 M${R - r} ${cy} q${r} ${-r * 1.4} ${r * 2} 0`} stroke={V("kids-ink")} strokeWidth={r * 0.55} fill="none" strokeLinecap="round" />;
  return (
    <g>
      <circle cx={L} cy={cy} r={r} fill={V("kids-ink")} /><circle cx={R} cy={cy} r={r} fill={V("kids-ink")} />
      <circle cx={L + r * 0.35} cy={cy - r * 0.35} r={r * 0.35} fill={V("kids-surface")} /><circle cx={R + r * 0.35} cy={cy - r * 0.35} r={r * 0.35} fill={V("kids-surface")} />
    </g>
  );
}

export function BuddyArt({ index, className = "size-full", label }: { index: number; className?: string; label?: string }) {
  const i = ((index % 12) + 12) % 12;
  const fill = V(`kids-${BODY[i]}-fill`), soft = V(`kids-${BODY[i]}-soft`);
  const top = {
    ears: <g><circle cx="28" cy="26" r="12" fill={fill} /><circle cx="72" cy="26" r="12" fill={fill} /></g>,
    antenna: <g><line x1="50" y1="6" x2="50" y2="22" stroke={V("kids-ink")} strokeWidth="4" /><circle cx="50" cy="7" r="6" fill={V("kids-star")} /></g>,
    leaf: <path d="M50 20 C38 2 24 8 28 18 C36 22 44 22 50 20Z" fill={V("kids-success")} />,
    horns: <path d="M28 26 L22 6 L38 20Z M72 26 L78 6 L62 20Z" fill={V("kids-ink")} />,
    tuft: <path d="M38 20 q6 -16 12 0 q6 -16 12 0" stroke={fill} strokeWidth="8" fill="none" strokeLinecap="round" />,
  }[TOP[i]];
  return (
    <svg viewBox="0 0 100 100" className={className} role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      {top}
      <rect x="12" y="20" width="76" height="74" rx={i % 3 === 0 ? 38 : 28} fill={fill} />
      <ellipse cx="50" cy="72" rx="24" ry="16" fill={soft} />
      <Eyes cx={50} cy={52} gap={12} r={6} happy={i % 4 === 1} />
      <path d="M43 66 q7 6.3 14 0" stroke={V("kids-ink")} strokeWidth={7 * 0.28} fill="none" strokeLinecap="round" />
    </svg>
  );
}
