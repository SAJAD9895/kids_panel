// Draws a picture reference from game content, as the app does (play_widgets.dart PictureView):
// our flat shapes (and their halves / gaps for "finish the shape"), a curated icon set drawn here,
// our characters, big letters and numbers, and counted groups. `asset:` images aren't wired yet in
// either app and show a neutral placeholder. Every colour is a design token.
import type { Picture } from "@/lib/engine";
import { describePicture, pictureColor, pictureName, pictureScheme, pictureSize } from "@/lib/engine";

const V = (n: string) => `var(--color-${n})`;
const PAINT: Record<string, string> = { red: V("kids-paint-red"), blue: V("kids-paint-blue"), yellow: V("kids-paint-yellow"), green: V("kids-paint-green"), purple: V("kids-paint-purple"), orange: V("kids-paint-orange") };
const SHAPE_COLOUR: Record<string, string> = { circle: V("kids-play-fill"), square: V("kids-learn-fill"), triangle: V("kids-me-fill"), star: V("kids-star"), heart: V("kids-play-ink") };
const scaleOf = (s: string | null) => (s === "small" ? 0.5 : s === "medium" ? 0.72 : 1);

function shapePath(shape: string): React.ReactNode {
  switch (shape) {
    case "circle": return <circle cx="50" cy="50" r="50" />;
    case "square": return <rect x="0" y="0" width="100" height="100" rx="12" />;
    case "triangle": return <polygon points="50,0 100,100 0,100" />;
    case "star": {
      const pts = Array.from({ length: 10 }, (_, i) => { const r = i % 2 === 0 ? 50 : 50 / 2.3; const a = -Math.PI / 2 + (i * Math.PI) / 5; return `${50 + r * Math.cos(a)},${50 + r * Math.sin(a)}`; }).join(" ");
      return <polygon points={pts} />;
    }
    case "heart": return <path d="M50 92 C20 70 0 52 0 30 C0 13 13 2 27 2 C38 2 46 9 50 18 C54 9 62 2 73 2 C87 2 100 13 100 30 C100 52 80 70 50 92Z" />;
    default: return <rect x="10" y="10" width="80" height="80" rx="20" />;
  }
}
const SIDE: Record<string, [number, number, number, number]> = { left: [0, 0, 50, 100], right: [50, 0, 50, 100], top: [0, 0, 100, 50], bottom: [0, 50, 100, 50] };
const OPP: Record<string, string> = { left: "right", right: "left", top: "bottom", bottom: "top" };

function Shape({ shape, fill, keep, missing, id }: { shape: string; fill: string; keep?: string; missing?: string; id: string }) {
  const clip = keep ?? (missing ? OPP[missing] : undefined);
  const r = clip ? SIDE[clip] ?? SIDE.left : null;
  return (
    <svg viewBox="-2 -2 104 104" className="size-4/5">
      {r && <defs><clipPath id={id}><rect x={r[0]} y={r[1]} width={r[2]} height={r[3]} /></clipPath></defs>}
      {missing && <g fill={V("kids-line")}>{shapePath(shape)}</g>}
      <g fill={fill} clipPath={r ? `url(#${id})` : undefined}>{shapePath(shape)}</g>
    </svg>
  );
}

// The icon set (same names as the app). Simple, friendly shapes drawn for this project.
const ICON_COLOUR: Record<string, string> = {
  cat: V("kids-play-ink"), dog: V("kids-listen-ink"), cow: V("kids-ink"), duck: V("kids-listen-ink"), fish: V("kids-watch-ink"), bird: V("kids-learn-ink"),
  apple: V("ui-danger"), banana: V("kids-listen-ink"), carrot: V("kids-play-ink"), sailboat: V("kids-learn-ink"), car: V("kids-play-ink"), ball: V("kids-learn-ink"),
  sun: V("kids-star"), moon: V("kids-learn-ink"), flower: V("kids-play-ink"), tree: V("kids-me-ink"), house: V("kids-play-ink"), cake: V("kids-play-ink"), water: V("kids-watch-ink"), star: V("kids-star"), pets: V("kids-play-ink"),
};
function IconArt({ name, color }: { name: string; color: string }) {
  const c = color, ink = V("kids-ink"), soft = V("kids-surface");
  const body: Record<string, React.ReactNode> = {
    cat: <><path d="M22 40 L26 12 L42 30 Q50 27 58 30 L74 12 L78 40 Q86 56 78 72 Q66 88 50 88 Q34 88 22 72 Q14 56 22 40Z" fill={c} /><circle cx="40" cy="54" r="4" fill={ink} /><circle cx="60" cy="54" r="4" fill={ink} /><path d="M46 66 Q50 70 54 66" stroke={ink} strokeWidth="3" fill="none" /></>,
    dog: <><ellipse cx="50" cy="56" rx="30" ry="28" fill={c} /><ellipse cx="22" cy="44" rx="10" ry="20" fill={c} /><ellipse cx="78" cy="44" rx="10" ry="20" fill={c} /><circle cx="40" cy="52" r="4" fill={ink} /><circle cx="60" cy="52" r="4" fill={ink} /><ellipse cx="50" cy="66" rx="7" ry="5" fill={ink} /></>,
    cow: <><rect x="20" y="28" width="60" height="56" rx="26" fill={soft} stroke={c} strokeWidth="5" /><circle cx="36" cy="44" r="8" fill={c} /><circle cx="64" cy="60" r="6" fill={c} /><ellipse cx="50" cy="72" rx="18" ry="10" fill={V("kids-play-soft")} /><path d="M24 30 L16 16 M76 30 L84 16" stroke={c} strokeWidth="5" strokeLinecap="round" /></>,
    duck: <><ellipse cx="54" cy="66" rx="34" ry="20" fill={V("kids-listen-fill")} /><circle cx="36" cy="38" r="16" fill={V("kids-listen-fill")} /><path d="M20 40 L6 44 L20 48Z" fill={V("kids-play-fill")} /><circle cx="34" cy="34" r="3" fill={ink} /></>,
    fish: <><ellipse cx="44" cy="50" rx="32" ry="20" fill={c} /><path d="M72 50 L94 32 L94 68Z" fill={c} /><circle cx="28" cy="46" r="4" fill={soft} /></>,
    bird: <><ellipse cx="50" cy="56" rx="30" ry="24" fill={c} /><path d="M40 50 Q52 34 66 50" fill={V("kids-learn-soft")} /><path d="M20 50 L6 54 L20 58Z" fill={V("kids-star")} /><circle cx="30" cy="48" r="3" fill={ink} /></>,
    apple: <><path d="M50 30 C30 18 10 32 14 56 C18 80 36 92 50 84 C64 92 82 80 86 56 C90 32 70 18 50 30Z" fill={c} /><path d="M50 30 Q52 16 60 10" stroke={V("kids-me-ink")} strokeWidth="5" fill="none" strokeLinecap="round" /><ellipse cx="62" cy="18" rx="8" ry="4" fill={V("kids-me-fill")} /></>,
    banana: <path d="M18 30 Q22 78 74 82 Q86 82 88 74 Q50 74 34 30 Q30 22 18 30Z" fill={V("kids-listen-fill")} stroke={c} strokeWidth="3" />,
    carrot: <><path d="M50 30 L66 34 L44 92 Z" fill={c} /><path d="M56 30 Q50 12 40 8 M58 30 Q62 12 72 10" stroke={V("kids-me-ink")} strokeWidth="5" fill="none" strokeLinecap="round" /></>,
    sailboat: <><path d="M14 70 L86 70 L74 86 L26 86Z" fill={c} /><path d="M50 14 L50 66 L82 66Z" fill={V("kids-learn-soft")} stroke={c} strokeWidth="3" /><path d="M46 24 L46 66 L22 66Z" fill={V("kids-play-fill")} /></>,
    car: <><rect x="8" y="46" width="84" height="26" rx="10" fill={c} /><path d="M26 46 L36 28 L66 28 L76 46Z" fill={c} /><rect x="38" y="32" width="12" height="12" fill={soft} /><rect x="54" y="32" width="12" height="12" fill={soft} /><circle cx="28" cy="74" r="10" fill={ink} /><circle cx="72" cy="74" r="10" fill={ink} /></>,
    ball: <><circle cx="50" cy="50" r="38" fill={c} /><path d="M14 44 Q50 60 86 44 M30 18 Q44 50 30 84 M70 18 Q56 50 70 84" stroke={soft} strokeWidth="4" fill="none" /></>,
    sun: <><circle cx="50" cy="50" r="22" fill={c} />{Array.from({ length: 8 }, (_, i) => { const a = (i * Math.PI) / 4; return <line key={i} x1={50 + 30 * Math.cos(a)} y1={50 + 30 * Math.sin(a)} x2={50 + 44 * Math.cos(a)} y2={50 + 44 * Math.sin(a)} stroke={c} strokeWidth="7" strokeLinecap="round" />; })}</>,
    moon: <path d="M62 12 A38 38 0 1 0 88 62 A30 30 0 1 1 62 12Z" fill={c} />,
    flower: <>{Array.from({ length: 6 }, (_, i) => { const a = (i * Math.PI) / 3; return <circle key={i} cx={50 + 20 * Math.cos(a)} cy={42 + 20 * Math.sin(a)} r="14" fill={c} />; })}<circle cx="50" cy="42" r="12" fill={V("kids-star")} /><path d="M50 56 L50 94" stroke={V("kids-me-ink")} strokeWidth="5" /></>,
    tree: <><rect x="44" y="60" width="12" height="32" fill={V("kids-play-ink")} /><circle cx="50" cy="42" r="30" fill={V("kids-me-fill")} stroke={c} strokeWidth="3" /></>,
    house: <><path d="M10 48 L50 12 L90 48Z" fill={c} /><rect x="20" y="46" width="60" height="44" fill={V("kids-listen-soft")} stroke={c} strokeWidth="4" /><rect x="42" y="62" width="16" height="28" fill={c} /></>,
    cake: <><rect x="16" y="50" width="68" height="38" rx="6" fill={V("kids-play-soft")} stroke={c} strokeWidth="4" /><path d="M16 62 Q33 72 50 62 Q67 72 84 62" stroke={c} strokeWidth="4" fill="none" /><rect x="46" y="30" width="8" height="20" fill={V("kids-learn-fill")} /><path d="M50 18 Q56 24 50 30 Q44 24 50 18Z" fill={V("kids-star")} /></>,
    water: <><path d="M6 40 Q20 28 34 40 Q48 52 62 40 Q76 28 94 40" stroke={c} strokeWidth="7" fill="none" strokeLinecap="round" /><path d="M6 62 Q20 50 34 62 Q48 74 62 62 Q76 50 94 62" stroke={c} strokeWidth="7" fill="none" strokeLinecap="round" /></>,
    star: <g fill={c}>{shapePath("star")}</g>,
  };
  body.pets = body.cat;
  return <svg viewBox="0 0 100 100" className="size-4/5">{body[name] ?? <rect x="14" y="14" width="72" height="72" rx="14" fill="none" stroke={V("kids-ink-muted")} strokeWidth="5" />}</svg>;
}

function CharacterArt({ name }: { name: string }) {
  const eyes = (cx: number, cy: number, gap: number, r: number) => (
    <path d={`M${cx - gap - r} ${cy} q${r} ${-r * 1.4} ${r * 2} 0 M${cx + gap - r} ${cy} q${r} ${-r * 1.4} ${r * 2} 0`} stroke={V("kids-ink")} strokeWidth={r * 0.55} fill="none" strokeLinecap="round" />
  );
  const smile = (cx: number, cy: number, w: number) => <path d={`M${cx - w} ${cy} q${w} ${w * 0.9} ${w * 2} 0`} stroke={V("kids-ink")} strokeWidth={w * 0.28} fill="none" strokeLinecap="round" />;
  if (name === "bolt") return (
    <svg viewBox="0 0 120 130" className="size-4/5"><line x1="60" y1="8" x2="60" y2="28" stroke={V("kids-ink")} strokeWidth="5" strokeLinecap="round" /><circle cx="60" cy="10" r="8" fill={V("kids-play-fill")} />
      <rect x="14" y="28" width="92" height="84" rx="30" fill={V("kids-learn-fill")} /><rect x="26" y="42" width="68" height="46" rx="18" fill={V("kids-learn-soft")} />{eyes(60, 62, 14, 6)}{smile(60, 74, 8)}
      <rect x="4" y="60" width="12" height="26" rx="6" fill={V("kids-learn-ink")} /><rect x="104" y="60" width="12" height="26" rx="6" fill={V("kids-learn-ink")} /></svg>
  );
  if (name === "nova") return (
    <svg viewBox="0 0 120 130" className="size-4/5"><path d="M60 8 L74 44 L112 46 L82 70 L93 108 L60 86 L27 108 L38 70 L8 46 L46 44 Z" fill={V("kids-listen-fill")} stroke={V("kids-listen-fill")} strokeWidth="10" strokeLinejoin="round" />{eyes(60, 58, 12, 6)}{smile(60, 72, 7)}</svg>
  );
  return (
    <svg viewBox="0 0 120 130" className="size-4/5"><path d="M60 30 C40 6 18 14 22 30 C34 34 50 34 60 30Z" fill={V("kids-success")} /><path d="M60 30 C80 4 104 12 98 28 C86 34 70 34 60 30Z" fill={V("kids-me-fill")} />
      <rect x="57" y="22" width="6" height="16" rx="3" fill={V("kids-success")} /><ellipse cx="60" cy="82" rx="46" ry="44" fill={V("kids-me-fill")} /><ellipse cx="60" cy="96" rx="30" ry="22" fill={V("kids-me-soft")} />{eyes(60, 74, 15, 7)}{smile(60, 90, 9)}</svg>
  );
}

/** A picture filling its box (the box sets the size). Decorative unless `label` is given. */
export function PictureView({ picture, label, className = "size-full" }: { picture: Picture; label?: boolean; className?: string }) {
  const scheme = pictureScheme(picture), name = pictureName(picture), paint = pictureColor(picture), size = pictureSize(picture);
  const parts = name.split(":");
  const id = `clip-${picture.value.replace(/[^a-z0-9]/gi, "")}`;
  const inner = (() => {
    switch (scheme) {
      case "shape": return <Shape id={id} shape={name} fill={(paint && PAINT[paint]) || SHAPE_COLOUR[name] || V("kids-watch-fill")} />;
      case "half": return <Shape id={id} shape={parts[0]} keep={parts[1] ?? "left"} fill={(paint && PAINT[paint]) || SHAPE_COLOUR[parts[0]] || V("kids-watch-fill")} />;
      case "gap": return <Shape id={id} shape={parts[0]} missing={parts[1] ?? "right"} fill={(paint && PAINT[paint]) || SHAPE_COLOUR[parts[0]] || V("kids-watch-fill")} />;
      case "icon": return <IconArt name={name} color={(paint && PAINT[paint]) || ICON_COLOUR[name] || V("kids-ink")} />;
      case "char": return <CharacterArt name={name} />;
      case "glyph": return <span className="font-display text-kids-display leading-none" style={{ color: paint ? PAINT[paint] : undefined, fontSize: "min(70cqw, 70cqh)" }}>{name}</span>;
      case "count": {
        const n = Math.max(1, Math.min(20, Number(parts[0]) || 1));
        const what = parts[1] ?? "star";
        return <span className={`grid size-full place-items-center ${n <= 4 ? "grid-cols-2" : "grid-cols-3"}`}>{Array.from({ length: n }, (_, i) => <span key={i} className="flex aspect-square w-full items-center justify-center"><IconArt name={what} color={ICON_COLOUR[what] ?? V("kids-ink")} /></span>)}</span>;
      }
      default: return <IconArt name="" color={V("kids-ink-muted")} />;
    }
  })();
  const s = scaleOf(size);
  return (
    <span className={`flex items-center justify-center [container-type:size] ${className}`} role={label ? "img" : undefined} aria-label={label ? describePicture(picture) : undefined} aria-hidden={label ? undefined : true}>
      <span className="flex items-center justify-center" style={{ width: `${s * 100}%`, height: `${s * 100}%` }}>{inner}</span>
    </span>
  );
}

/** Piece [index] (row by row) of a picture cut into [grid] × [grid]. */
export function PictureSlice({ picture, index, grid }: { picture: Picture; index: number; grid: number }) {
  const col = index % grid, row = Math.floor(index / grid);
  return (
    <span className="relative block size-full overflow-hidden" aria-hidden>
      <span className="absolute" style={{ width: `${grid * 100}%`, height: `${grid * 100}%`, left: `${-col * 100}%`, top: `${-row * 100}%` }}>
        <PictureView picture={picture} />
      </span>
    </span>
  );
}
