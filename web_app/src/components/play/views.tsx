"use client";
// The item views: what a child taps, drags, flips or draws for each kind of item. Every view
// works with a mouse, a finger (Pointer Events) and a keyboard: dragging has a tap-to-pick /
// tap-to-place alternative, and every piece is a real <button>. The engine judges the answer.
import { useEffect, useMemo, useRef, useState } from "react";
import {
  choiceSpoken, fits, jigsawIndexOf, memory as memoryAnswer, order as orderAnswer, pairOf, pick, pieceOf, place, standardRegistry,
  textOf, trace as traceAnswer,
  type Choice, type ChoiceSpec, type Hint, type ItemAnswer, type JigsawSpec, type MemorySpec, type OrderSpec, type PlaceSpec, type Pt, type TraceSpec,
} from "@/lib/engine";
import { PictureSlice, PictureView } from "./picture";
import { speak } from "./speech";

type ViewProps<S> = { spec: S; hint: Hint; disabled: boolean; onAnswer: (a: ItemAnswer) => void };
const registry = standardRegistry();

const tile = "flex items-center justify-center rounded-xl bg-kids-surface shadow-kid-raised transition-transform active:scale-95 active:shadow-kid-pressed disabled:opacity-40 focus-visible:outline-4 focus-visible:outline-kids-focus";

/** One option, piece or card face: its picture, its label, or both. */
function Face({ c, big = false }: { c: Choice; big?: boolean }) {
  const label = textOf(c.label);
  return (
    <span className="flex size-full flex-col items-center justify-center gap-s1 p-s2">
      {c.picture && <span className={big ? "size-kids-node" : "size-tap-kids"}><PictureView picture={c.picture} /></span>}
      {label && <span className={`font-display leading-none ${c.picture ? "text-kids-label" : big ? "text-kids-display" : "text-kids-title"}`}>{label}</span>}
    </span>
  );
}

// ---------------------------------------------------------------------------- choices
export function ChoiceView({ spec, hint, disabled, onAnswer }: ViewProps<ChoiceSpec>) {
  const [picked, setPicked] = useState<string[]>([]);
  useEffect(() => setPicked([]), [spec.id]);
  const gone = new Set(hint.eliminate);
  const cols = spec.options.length <= 2 ? "grid-cols-2" : spec.options.length === 4 ? "grid-cols-2 md:grid-cols-4" : "grid-cols-2 md:grid-cols-3";
  const tap = (id: string) => {
    speak(choiceSpoken(spec.options.find((o) => o.id === id)!));
    if (!spec.multi) return onAnswer(pick(id));
    setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]));
  };
  return (
    <div className="flex flex-col gap-s5">
      {spec.sentence && <p className="text-center font-reading text-kids-reading-lg">{textOf(spec.sentence).replace("___", "_____")}</p>}
      {spec.countPicture && spec.count !== null && (
        <div className="mx-auto grid max-w-ui-form-w grid-cols-5 gap-s2" role="img" aria-label={`${spec.count} to count`}>
          {Array.from({ length: spec.count }, (_, i) => <span key={i} className="aspect-square"><PictureView picture={spec.countPicture!} /></span>)}
        </div>
      )}
      {spec.equation && (
        <div className="flex flex-wrap items-center justify-center gap-s4 font-display text-kids-display" aria-label={`${spec.equation.a} ${spec.equation.op === "+" ? "plus" : "minus"} ${spec.equation.b}`}>
          <Group n={spec.equation.a} pic={spec.equation.picture} /><span aria-hidden>{spec.equation.op}</span><Group n={spec.equation.b} pic={spec.equation.picture} /><span aria-hidden>=</span><span aria-hidden>?</span>
        </div>
      )}
      <div className={`mx-auto grid w-full gap-s4 ${spec.options.length <= 4 ? "max-w-ui-form-w" : "max-w-ui-content-max"} ${cols}`} role="group" aria-label="Answers">
        {spec.options.map((o) => (
          <button key={o.id} type="button" disabled={disabled || gone.has(o.id)} onClick={() => tap(o.id)} aria-pressed={spec.multi ? picked.includes(o.id) : undefined}
            aria-label={choiceSpoken(o) || undefined}
            className={`${tile} aspect-square min-h-tap-kids-xl ${picked.includes(o.id) ? "ring-4 ring-kids-learn-fill" : ""} ${hint.reveal.includes(o.id) ? "ring-4 ring-kids-star" : ""}`}>
            <Face c={o} big={spec.style === "glyph"} />
          </button>
        ))}
      </div>
      {spec.multi && <button type="button" disabled={disabled || !picked.length} onClick={() => onAnswer(pick(...picked))} className={`${tile} min-h-tap-kids self-center bg-kids-me-fill px-s8 font-display text-kids-label`}>Done</button>}
    </div>
  );
}
function Group({ n, pic }: { n: number; pic: ChoiceSpec["countPicture"] }) {
  if (!pic) return <span>{n}</span>;
  return <span className="grid grid-cols-5 gap-s1" aria-hidden>{Array.from({ length: n }, (_, i) => <span key={i} className="size-tap-kids-secondary"><PictureView picture={pic} /></span>)}</span>;
}

// ---------------------------------------------------------------------------- drag and drop
/** Pointer dragging with a floating copy; drops land on the element marked data-drop under the finger. */
function useDrag(onDrop: (token: string, target: string | null) => void) {
  const [drag, setDrag] = useState<{ id: string; x: number; y: number; w: number; h: number } | null>(null);
  const start = useRef<{ x: number; y: number; moved: boolean } | null>(null);
  const dragged = useRef(false);
  const handlers = (id: string) => ({
    onPointerDown: (e: React.PointerEvent<HTMLElement>) => {
      if (e.button !== 0) return;
      const r = e.currentTarget.getBoundingClientRect();
      start.current = { x: e.clientX, y: e.clientY, moved: false };
      e.currentTarget.setPointerCapture(e.pointerId);
      setDrag({ id, x: e.clientX - r.width / 2, y: e.clientY - r.height / 2, w: r.width, h: r.height });
    },
    onPointerMove: (e: React.PointerEvent<HTMLElement>) => {
      if (!start.current || !drag || drag.id !== id) return;
      if (Math.hypot(e.clientX - start.current.x, e.clientY - start.current.y) > 8) start.current.moved = true;
      setDrag({ ...drag, x: e.clientX - drag.w / 2, y: e.clientY - drag.h / 2 });
    },
    onPointerUp: (e: React.PointerEvent<HTMLElement>) => {
      const moved = start.current?.moved;
      start.current = null;
      setDrag(null);
      if (!moved) return; // a tap: handled by onClick (tap to pick, tap to place)
      dragged.current = true; // the click that follows a drag isn't a tap
      const under = document.elementsFromPoint(e.clientX, e.clientY).find((el) => (el as HTMLElement).dataset?.drop);
      onDrop(id, (under as HTMLElement | undefined)?.dataset.drop ?? null);
    },
    onPointerCancel: () => { start.current = null; setDrag(null); },
  });
  const wasDrag = () => { const d = dragged.current; dragged.current = false; return d; };
  return { drag, handlers, wasDrag };
}

export function PlaceView({ spec, hint, disabled, onAnswer }: ViewProps<PlaceSpec | JigsawSpec>) {
  const [placed, setPlaced] = useState<Record<string, string>>({});
  const [selected, setSelected] = useState<string | null>(null);
  const [bounce, setBounce] = useState<string | null>(null);
  const mistakes = useRef(0);
  useEffect(() => { setPlaced({}); setSelected(null); mistakes.current = 0; }, [spec.id]);
  const drop = (token: string, target: string | null) => {
    setSelected(null);
    if (!target || placed[token]) return;
    if (!fits(spec, token, target)) {
      mistakes.current += 1;
      setBounce(token); setTimeout(() => setBounce(null), 450);
      speak("Not there. Try another place.");
      return;
    }
    const next = { ...placed, [token]: target };
    setPlaced(next);
    if (Object.keys(next).length === spec.tokens.length) onAnswer(place(next, mistakes.current));
  };
  const { drag, handlers, wasDrag } = useDrag(drop);
  const jig = spec.kind === "jigsaw";
  const tokenFace = (t: Choice) => (jig ? <span className="block size-full"><PictureSlice picture={(spec as JigsawSpec).picture} index={jigsawIndexOf(t.id)} grid={(spec as JigsawSpec).grid} /></span> : <Face c={t} />);
  const free = spec.tokens.filter((t) => !placed[t.id]);
  const targetBox = (tg: Choice) => {
    const inside = spec.tokens.filter((t) => placed[t.id] === tg.id);
    return (
      <button key={tg.id} type="button" data-drop={tg.id} disabled={disabled} onClick={() => selected && drop(selected, tg.id)}
        aria-label={jig ? `Space ${jigsawIndexOf(tg.id) + 1}` : `${choiceSpoken(tg) || "Place"}${inside.length ? `, has ${inside.map((t) => choiceSpoken(t)).join(", ")}` : ""}`}
        className={`relative flex min-h-kids-node flex-col items-center justify-center gap-s2 rounded-xl border-4 border-dashed p-s2 ${jig ? "aspect-square border-kids-line bg-kids-bg-alt p-0" : "border-kids-line bg-kids-surface"} ${selected ? "border-kids-learn-fill" : ""} ${hint.reveal.includes(tg.id) ? "ring-4 ring-kids-star" : ""}`}>
        {jig ? (inside[0] ? <span className="absolute inset-0">{tokenFace(inside[0])}</span> : null) : <><Face c={tg} /><span className="flex flex-wrap justify-center gap-s1">{inside.map((t) => <span key={t.id} className="size-tap-kids rounded-lg bg-kids-me-soft">{tokenFace(t)}</span>)}</span></>}
      </button>
    );
  };
  return (
    <div className="flex flex-col gap-s6">
      {jig ? (
        <div className="mx-auto grid w-full max-w-ui-form-w gap-s1" style={{ gridTemplateColumns: `repeat(${(spec as JigsawSpec).grid}, minmax(0, 1fr))` }} role="group" aria-label="Board">{spec.targets.map(targetBox)}</div>
      ) : (
        <div className={`grid gap-s4 ${spec.targets.length <= 2 ? "grid-cols-2" : "grid-cols-2 md:grid-cols-3"}`} role="group" aria-label="Places">{spec.targets.map(targetBox)}</div>
      )}
      <div className="flex flex-wrap justify-center gap-s3" role="group" aria-label="Pieces to place">
        {free.map((t) => (
          <button key={t.id} type="button" disabled={disabled} {...handlers(t.id)} onClick={() => { if (wasDrag()) return; setSelected((s) => (s === t.id ? null : t.id)); speak(choiceSpoken(t)); }}
            aria-pressed={selected === t.id} aria-label={jig ? `Piece ${jigsawIndexOf(t.id) + 1}` : choiceSpoken(t) || "Piece"}
            className={`${tile} touch-none select-none ${jig ? "size-kids-node p-0 overflow-hidden" : "min-h-kids-node min-w-kids-node"} ${selected === t.id ? "ring-4 ring-kids-learn-fill" : ""} ${bounce === t.id ? "wiggle" : ""} ${drag?.id === t.id ? "opacity-30" : ""} ${hint.reveal.includes(t.id) ? "ring-4 ring-kids-star" : ""}`}>
            {tokenFace(t)}
          </button>
        ))}
      </div>
      <p className="text-center text-kids-caption text-kids-ink-muted">Drag a piece to its place, or tap a piece and then tap where it goes.</p>
      {drag && (
        <span className="pointer-events-none fixed z-50 overflow-hidden rounded-xl bg-kids-surface opacity-90 shadow-kid-raised" style={{ left: drag.x, top: drag.y, width: drag.w, height: drag.h }} aria-hidden>
          {tokenFace(spec.tokens.find((t) => t.id === drag.id)!)}
        </span>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------- order
export function OrderView({ spec, hint, disabled, onAnswer }: ViewProps<OrderSpec>) {
  return spec.kind === "word_build" ? <WordBuild spec={spec} hint={hint} disabled={disabled} onAnswer={onAnswer} /> : <SwapPuzzle spec={spec} hint={hint} disabled={disabled} onAnswer={onAnswer} />;
}

/** Word building: tap letters to fill the spaces in order; tap a filled space to take it back. */
function WordBuild({ spec, hint, disabled, onAnswer }: ViewProps<OrderSpec>) {
  const [built, setBuilt] = useState<string[]>([]);
  useEffect(() => setBuilt([]), [spec.id]);
  const add = (id: string) => {
    const next = [...built, id];
    speak(textOf(pieceOf(spec, id).label));
    setBuilt(next);
    if (next.length === spec.order.length) { onAnswer(orderAnswer(next)); setTimeout(() => setBuilt([]), 600); }
  };
  return (
    <div className="flex flex-col items-center gap-s6">
      {spec.picture && <span className="size-kids-art-lg"><PictureView picture={spec.picture} label /></span>}
      <div className="flex flex-wrap justify-center gap-s2" aria-label="Your word" role="group">
        {spec.order.map((_, i) => {
          const id = built[i];
          return (
            <button key={i} type="button" disabled={disabled || !id} onClick={() => setBuilt(built.slice(0, i))} aria-label={id ? `Letter ${textOf(pieceOf(spec, id).label)}, tap to take back` : `Space ${i + 1}`}
              className={`flex size-tap-kids-xl items-center justify-center rounded-lg border-b-4 font-display text-kids-title ${id ? "border-kids-learn-fill bg-kids-learn-soft" : "border-kids-line"}`}>
              {id ? textOf(pieceOf(spec, id).label) : ""}
            </button>
          );
        })}
      </div>
      <div className="flex flex-wrap justify-center gap-s3" role="group" aria-label="Letters">
        {spec.start.filter((id) => !built.includes(id)).map((id) => (
          <button key={id} type="button" disabled={disabled} onClick={() => add(id)} className={`${tile} size-tap-kids-xl font-display text-kids-title ${hint.reveal.includes(id) ? "ring-4 ring-kids-star" : ""}`}>
            {textOf(pieceOf(spec, id).label)}
          </button>
        ))}
      </div>
    </div>
  );
}

/** Swap puzzle: tap (or drag) one piece onto another to swap them; it's checked after each swap. */
function SwapPuzzle({ spec, hint, disabled, onAnswer }: ViewProps<OrderSpec>) {
  const [arr, setArr] = useState<string[]>([...spec.start]);
  const [sel, setSel] = useState<string | null>(null);
  useEffect(() => { setArr([...spec.start]); setSel(null); }, [spec]);
  const swap = (a: string, b: string | null) => {
    setSel(null);
    if (!b || a === b) return;
    const next = [...arr]; const i = next.indexOf(a), j = next.indexOf(b);
    [next[i], next[j]] = [next[j], next[i]];
    setArr(next);
    if (registry.evaluate(spec, orderAnswer(next)).correct) onAnswer(orderAnswer(next));
  };
  const { drag, handlers, wasDrag } = useDrag(swap);
  const cols = spec.columns || Math.min(arr.length, 4);
  const face = (id: string) => (spec.columns && spec.picture ? <PictureSlice picture={spec.picture} index={Number(id.slice(1))} grid={spec.columns} /> : <Face c={pieceOf(spec, id)} />);
  return (
    <div className="flex flex-col items-center gap-s4">
      <div className="grid w-full max-w-ui-form-w gap-s1" style={{ gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))` }} role="group" aria-label="Puzzle">
        {arr.map((id, i) => (
          <button key={id} type="button" data-drop={id} data-piece={id} disabled={disabled} {...handlers(id)} onClick={() => { if (wasDrag()) return; if (sel) swap(sel, id); else setSel(id); }} aria-pressed={sel === id}
            aria-label={`Piece in place ${i + 1}${sel === id ? ", picked" : ""}`}
            className={`aspect-square touch-none select-none overflow-hidden rounded-md bg-kids-surface ${sel === id ? "ring-4 ring-kids-learn-fill" : ""} ${hint.reveal.includes(id) ? "ring-4 ring-kids-star" : ""} ${drag?.id === id ? "opacity-40" : ""}`}>
            {face(id)}
          </button>
        ))}
      </div>
      {drag && <span className="pointer-events-none fixed z-50 overflow-hidden rounded-md opacity-90 shadow-kid-raised" style={{ left: drag.x, top: drag.y, width: drag.w, height: drag.h }} aria-hidden>{face(drag.id)}</span>}
      <p className="text-kids-caption text-kids-ink-muted">Tap two pieces to swap them, or drag one onto another.</p>
      {spec.picture && spec.columns > 0 && <details className="text-kids-caption"><summary className="cursor-pointer font-bold">Peek at the picture</summary><span className="mt-s2 block size-kids-node"><PictureView picture={spec.picture} /></span></details>}
    </div>
  );
}

// ---------------------------------------------------------------------------- memory
export function MemoryView({ spec, hint, disabled, onAnswer }: ViewProps<MemorySpec>) {
  const [up, setUp] = useState<string[]>([]);
  const [found, setFound] = useState<string[]>([]);
  const flips = useRef(0);
  const started = useRef(Date.now());
  const [now, setNow] = useState(Date.now());
  useEffect(() => { setUp([]); setFound([]); flips.current = 0; started.current = Date.now(); }, [spec.id]);
  useEffect(() => { if (!spec.timer) return; const id = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(id); }, [spec.timer]);
  const turn = (id: string) => {
    if (up.length === 2 || up.includes(id) || found.includes(pairOf(id))) return;
    const card = spec.cards.find((c) => c.id === id)!;
    speak(choiceSpoken(card));
    const next = [...up, id];
    setUp(next);
    if (next.length < 2) return;
    flips.current += 1;
    if (pairOf(next[0]) === pairOf(next[1])) {
      const f = [...found, pairOf(id)];
      setTimeout(() => { setFound(f); setUp([]); if (f.length === spec.pairs) onAnswer(memoryAnswer(flips.current, f.length, spec.timer ? Date.now() - started.current : null)); }, 350);
    } else setTimeout(() => setUp([]), 900);
  };
  const cols = spec.cards.length <= 6 ? "grid-cols-3" : spec.cards.length <= 8 ? "grid-cols-4" : "grid-cols-4 md:grid-cols-6";
  return (
    <div className="flex flex-col gap-s4">
      <p className="text-center text-kids-body" aria-live="polite">{found.length} of {spec.pairs} pairs{spec.timer ? ` · ${Math.floor((now - started.current) / 1000)} s` : ""}</p>
      <div className={`mx-auto grid w-full max-w-ui-content-max gap-s3 ${cols}`} role="group" aria-label="Cards">
        {spec.cards.map((c, i) => {
          const shown = up.includes(c.id) || found.includes(pairOf(c.id));
          return (
            <button key={c.id} type="button" disabled={disabled || found.includes(pairOf(c.id))} onClick={() => turn(c.id)}
              aria-label={shown ? `Card ${i + 1}: ${choiceSpoken(c)}` : `Card ${i + 1}, face down`}
              className={`${tile} aspect-square ${shown ? "pop bg-kids-surface" : "bg-kids-learn-fill"} ${found.includes(pairOf(c.id)) ? "opacity-60" : ""} ${hint.reveal.includes(c.id) ? "ring-4 ring-kids-star" : ""}`}>
              {shown ? <Face c={c} /> : <span className="font-display text-kids-title text-kids-surface" aria-hidden>?</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------- tracing
export function TraceView({ spec, hint, disabled, onAnswer }: ViewProps<TraceSpec>) {
  const [strokes, setStrokes] = useState<Pt[][]>([]);
  const drawing = useRef<Pt[] | null>(null);
  const box = useRef<SVGSVGElement>(null);
  useEffect(() => setStrokes([]), [spec.id]);
  const at = (e: React.PointerEvent): Pt => {
    const r = box.current!.getBoundingClientRect();
    return { x: Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)), y: Math.min(1, Math.max(0, (e.clientY - r.top) / r.height)) };
  };
  const guide = useMemo(() => spec.strokes.map((s) => s.map((p) => `${p.x * 100},${p.y * 100}`).join(" ")), [spec.strokes]);
  const line = (s: readonly Pt[]) => s.map((p) => `${p.x * 100},${p.y * 100}`).join(" ");
  return (
    <div className="flex flex-col items-center gap-s4">
      <svg ref={box} viewBox="0 0 100 100" className="aspect-square w-full max-w-ui-form-w touch-none rounded-xl bg-kids-surface shadow-kid-raised" role="img" aria-label={`Trace ${spec.glyph ?? "the shape"} with your finger or the mouse`}
        onPointerDown={(e) => { if (disabled) return; e.currentTarget.setPointerCapture(e.pointerId); drawing.current = [at(e)]; setStrokes((s) => [...s, drawing.current!]); }}
        onPointerMove={(e) => { if (!drawing.current) return; drawing.current = [...drawing.current, at(e)]; const d = drawing.current; setStrokes((s) => [...s.slice(0, -1), d]); }}
        onPointerUp={() => { drawing.current = null; }}>
        {guide.map((g, i) => <polyline key={i} points={g} fill="none" stroke="var(--color-kids-line)" strokeWidth="12" strokeLinecap="round" strokeLinejoin="round" />)}
        {guide.map((g, i) => <polyline key={`d${i}`} points={g} fill="none" stroke="var(--color-kids-ink-muted)" strokeWidth="1.2" strokeDasharray="2 3" />)}
        {spec.strokes.map((s, i) => s[0] && <circle key={`s${i}`} cx={s[0].x * 100} cy={s[0].y * 100} r={hint.reveal.length ? 5 : 3} fill="var(--color-kids-success)" />)}
        {strokes.map((s, i) => <polyline key={`u${i}`} points={line(s)} fill="none" stroke="var(--color-kids-learn-fill)" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" />)}
      </svg>
      <div className="flex gap-s3">
        <button type="button" onClick={() => setStrokes([])} disabled={disabled || !strokes.length} className={`${tile} min-h-tap-kids px-s6 font-bold`}>Start again</button>
        <button type="button" onClick={() => onAnswer(traceAnswer(strokes))} disabled={disabled || !strokes.length} className={`${tile} min-h-tap-kids bg-kids-me-fill px-s6 font-display text-kids-label`}>Done</button>
      </div>
      <p className="text-kids-caption text-kids-ink-muted">Start at the green dot. Keyboard players can skip with the hint button.</p>
    </div>
  );
}
