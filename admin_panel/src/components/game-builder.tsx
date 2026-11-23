"use client";
// Builds games.config in the learning engine's format, checked live against the engine's own
// JSON Schema, with a preview of every item as the engine will read it.
import { useMemo, useState } from "react";
import { allItems, describe, formFromItem, itemFromForm, type GameConfig, type Item, type Level } from "@/lib/game/config";
import { kindOf, KINDS, PICTURE_HELP, type Field } from "@/lib/game/kinds";
import { validateConfig } from "@/lib/game/validate";

const input = "w-full rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui text-ui-body";
const btn = "min-h-tap-ui rounded-md border border-ui-border-input bg-ui-bg px-s4 text-ui-body hover:bg-ui-surface disabled:opacity-50";
const primary = "min-h-tap-ui rounded-md bg-ui-primary px-s5 text-ui-body-strong text-ui-on-primary hover:bg-ui-primary-hover disabled:opacity-50";

function toLevels(c: GameConfig): Level[] {
  if (c.levels?.length) return c.levels;
  return [{ id: "all", label: "All", items: c.items ?? [] }];
}

export function GameBuilder({ initial, save, canWrite, starsPerGame }: {
  initial: GameConfig; save: (c: GameConfig) => Promise<{ error?: string }>; canWrite: boolean; starsPerGame: number;
}) {
  const [useLevels, setUseLevels] = useState(!!initial.levels?.length);
  const [levels, setLevels] = useState<Level[]>(toLevels(initial));
  const [intro, setIntro] = useState(typeof initial.intro === "string" ? initial.intro : initial.intro?.text ?? "");
  const [editing, setEditing] = useState<{ level: number; index: number | null; kind: string } | null>(null);
  const [msg, setMsg] = useState<{ tone: "ok" | "err"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const config: GameConfig = useMemo(() => {
    const c: GameConfig = {};
    if (intro.trim()) c.intro = { text: intro.trim(), speak: intro.trim() };
    if (useLevels) c.levels = levels.map((l) => ({ ...l, label: l.label || undefined }));
    else c.items = levels[0]?.items ?? [];
    return c;
  }, [intro, levels, useLevels]);
  const problems = useMemo(() => validateConfig(config), [config]);

  const setItems = (li: number, fn: (items: Item[]) => Item[]) =>
    setLevels((ls) => ls.map((l, i) => (i === li ? { ...l, items: fn(l.items) } : l)));
  const move = (li: number, i: number, d: number) => setItems(li, (items) => {
    const out = [...items];
    const j = i + d;
    if (j < 0 || j >= out.length) return out;
    [out[i], out[j]] = [out[j], out[i]];
    return out;
  });

  async function onSave() {
    setBusy(true);
    setMsg(null);
    const r = await save(config);
    setMsg(r.error ? { tone: "err", text: r.error } : { tone: "ok", text: "Game saved." });
    setBusy(false);
  }

  return (
    <div className="flex flex-col gap-s6">
      <p className="text-ui-small text-ui-text-muted">
        Finishing this game earns {starsPerGame} star{starsPerGame === 1 ? "" : "s"} a day (reward rules), plus any goal and badge bonuses. {PICTURE_HELP}
      </p>
      <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">Introduction (read aloud before the game)</span>
        <input value={intro} onChange={(e) => setIntro(e.target.value)} disabled={!canWrite} maxLength={200} className={input} /></label>
      <label className="flex items-center gap-s3">
        <input type="checkbox" checked={useLevels} disabled={!canWrite} className="size-icon-md accent-ui-primary"
          onChange={(e) => { setUseLevels(e.target.checked); if (e.target.checked && levels[0]?.id === "all") setLevels([{ ...levels[0], id: "easy", label: "Easy" }]); }} />
        <span><span className="text-ui-body-strong">Difficulty levels</span><span className="block text-ui-small text-ui-text-muted">2–5 levels, easiest first; children get the hardest level they&apos;re old enough for.</span></span>
      </label>

      {levels.map((l, li) => (
        <section key={li} className="rounded-lg border border-ui-border p-s5" aria-label={useLevels ? `Level ${l.label || l.id}` : "Items"}>
          {useLevels && (
            <div className="mb-s4 grid gap-s3 md:grid-cols-5">
              <label className="flex flex-col gap-s1 text-ui-small">Level id
                <input value={l.id} disabled={!canWrite} onChange={(e) => setLevels((ls) => ls.map((x, i) => (i === li ? { ...x, id: e.target.value } : x)))} className={input} /></label>
              <label className="flex flex-col gap-s1 text-ui-small">Label
                <input value={l.label ?? ""} disabled={!canWrite} onChange={(e) => setLevels((ls) => ls.map((x, i) => (i === li ? { ...x, label: e.target.value } : x)))} className={input} /></label>
              <label className="flex flex-col gap-s1 text-ui-small">From age (months)
                <input type="number" min={0} max={144} value={l.minAgeMonths ?? ""} disabled={!canWrite}
                  onChange={(e) => setLevels((ls) => ls.map((x, i) => (i === li ? { ...x, minAgeMonths: e.target.value === "" ? undefined : Number(e.target.value) } : x)))} className={input} /></label>
              <label className="flex flex-col gap-s1 text-ui-small">Options shown
                <input type="number" min={2} max={8} value={l.options ?? ""} disabled={!canWrite}
                  onChange={(e) => setLevels((ls) => ls.map((x, i) => (i === li ? { ...x, options: e.target.value === "" ? undefined : Number(e.target.value) } : x)))} className={input} /></label>
              <label className="flex flex-col gap-s1 text-ui-small">Tries
                <input type="number" min={1} max={5} value={l.attempts ?? ""} disabled={!canWrite}
                  onChange={(e) => setLevels((ls) => ls.map((x, i) => (i === li ? { ...x, attempts: e.target.value === "" ? undefined : Number(e.target.value) } : x)))} className={input} /></label>
            </div>
          )}
          <ol className="flex flex-col gap-s3">
            {l.items.map((it, i) => (
              <li key={i} className="flex flex-wrap items-center justify-between gap-s3 rounded-md bg-ui-surface p-s3">
                <span className="min-w-0 flex-1 break-words text-ui-body">{i + 1}. {describe(it)}</span>
                {canWrite && (
                  <span className="flex gap-s2">
                    <button type="button" className={btn} onClick={() => move(li, i, -1)} aria-label={`Move item ${i + 1} up`}>↑</button>
                    <button type="button" className={btn} onClick={() => move(li, i, 1)} aria-label={`Move item ${i + 1} down`}>↓</button>
                    <button type="button" className={btn} onClick={() => setEditing({ level: li, index: i, kind: it.kind })}>Edit</button>
                    <button type="button" className={btn} onClick={() => setItems(li, (items) => items.filter((_, j) => j !== i))}>Remove</button>
                  </span>
                )}
              </li>
            ))}
            {l.items.length === 0 && <li className="text-ui-small text-ui-text-muted">No items yet.</li>}
          </ol>
          {canWrite && (
            <div className="mt-s4 flex flex-wrap items-end gap-s3">
              <label className="flex flex-col gap-s1 text-ui-small">Add an item
                <select className={input} defaultValue="" onChange={(e) => { if (e.target.value) setEditing({ level: li, index: null, kind: e.target.value }); e.target.value = ""; }}>
                  <option value="">Choose a kind…</option>
                  {[...new Set(KINDS.map((k) => k.family))].map((f) => (
                    <optgroup key={f} label={f}>{KINDS.filter((k) => k.family === f).map((k) => <option key={k.kind} value={k.kind}>{k.label}</option>)}</optgroup>
                  ))}
                </select></label>
              {useLevels && levels.length > 1 && <button type="button" className={btn} onClick={() => setLevels((ls) => ls.filter((_, i) => i !== li))}>Remove level</button>}
            </div>
          )}
          {editing?.level === li && (
            <ItemForm key={`${editing.index}-${editing.kind}`} kind={editing.kind} initial={editing.index === null ? {} : formFromItem(l.items[editing.index])}
              onCancel={() => setEditing(null)}
              onDone={(item) => { setItems(li, (items) => (editing.index === null ? [...items, item] : items.map((x, j) => (j === editing.index ? item : x)))); setEditing(null); }} />
          )}
        </section>
      ))}
      {canWrite && useLevels && levels.length < 5 && (
        <button type="button" className={btn} onClick={() => setLevels((ls) => [...ls, { id: `level-${ls.length + 1}`, label: "", items: [] }])}>Add a level</button>
      )}

      <section aria-label="Checks" className={`rounded-md p-s4 ${problems.length ? "bg-ui-warning-soft text-ui-warning-text" : "bg-ui-success-soft text-ui-success"}`}>
        {problems.length ? (
          <><p className="text-ui-body-strong">The app can&apos;t play this yet:</p>
            <ul className="mt-s2 list-disc pl-s6 text-ui-small">{problems.slice(0, 8).map((p) => <li key={p.path + p.message}>{p.path} {p.message}</li>)}</ul></>
        ) : <p className="text-ui-body-strong">Valid for the learning engine ({allItems(config).length} items).</p>}
      </section>

      <Preview config={config} />

      {msg && <p role={msg.tone === "err" ? "alert" : "status"} className={msg.tone === "err" ? "text-ui-danger" : "text-ui-success"}>{msg.text}</p>}
      {canWrite && <div><button type="button" onClick={onSave} disabled={busy || problems.length > 0} className={primary}>{busy ? "Saving…" : "Save game"}</button></div>}
    </div>
  );
}

function ItemForm({ kind, initial, onDone, onCancel }: { kind: string; initial: Record<string, string>; onDone: (i: Item) => void; onCancel: () => void }) {
  const k = kindOf(kind)!;
  const [error, setError] = useState<string | null>(null);
  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const raw = Object.fromEntries(new FormData(e.currentTarget).entries()) as Record<string, string>;
    const missing = k.fields.filter((f) => f.required && !(raw[f.name] ?? "").trim()).map((f) => f.label);
    if (missing.length) return setError(`Fill in: ${missing.join(", ")}`);
    try {
      const item = itemFromForm(kind, raw);
      const p = validateConfig({ items: [item] });
      if (p.length) return setError(p.map((x) => `${x.path} ${x.message}`).join("; "));
      onDone(item);
    } catch (err) {
      setError(err instanceof Error ? err.message : "That item isn't valid.");
    }
  }
  return (
    <form onSubmit={submit} className="mt-s4 flex flex-col gap-s4 rounded-md border border-ui-primary p-s5" aria-label={`${k.label} item`}>
      <p className="text-ui-body-strong">{k.label} <span className="text-ui-small font-normal text-ui-text-muted">· {k.summary}</span></p>
      {k.fields.map((f) => <FieldInput key={f.name} f={f} value={initial[f.name]} />)}
      {error && <p role="alert" className="text-ui-small text-ui-danger">{error}</p>}
      <div className="flex gap-s3"><button className={primary}>Keep this item</button><button type="button" className={btn} onClick={onCancel}>Cancel</button></div>
    </form>
  );
}

function FieldInput({ f, value }: { f: Field; value?: string }) {
  const id = `item-${f.name}`;
  const label = <label htmlFor={id} className="text-ui-body-strong">{f.label}{f.required ? " *" : ""}</label>;
  const help = f.help && <span className="text-ui-small text-ui-text-muted">{f.help}</span>;
  if (f.type === "bool") return <label className="flex items-center gap-s3"><input id={id} type="checkbox" name={f.name} defaultChecked={value === "on"} className="size-icon-md accent-ui-primary" />{f.label}</label>;
  if (f.type === "enum") return (
    <div className="flex flex-col gap-s1">{label}<select id={id} name={f.name} defaultValue={value ?? ""} className={input}><option value="">—</option>{f.options!.map((o) => <option key={o}>{o}</option>)}</select>{help}</div>
  );
  if (["choices", "answers", "pairs", "bins"].includes(f.type)) return (
    <div className="flex flex-col gap-s1">{label}<textarea id={id} name={f.name} rows={4} defaultValue={value} className={`${input} py-s2`} />{help}</div>
  );
  return (
    <div className="flex flex-col gap-s1">{label}<input id={id} name={f.name} defaultValue={value} type={f.type === "int" ? "number" : "text"} min={f.min} max={f.max} className={input} />{help}</div>
  );
}

/** How the engine will read the game: each item, its question, options (✓ = correct) and hint. */
function Preview({ config }: { config: GameConfig }) {
  const items = allItems(config);
  return (
    <section aria-label="Preview" className="rounded-lg border border-ui-border p-s5">
      <h3 className="text-ui-h3">Preview</h3>
      <p className="mb-s4 text-ui-small text-ui-text-muted">What each item asks and accepts. Play it in the app&apos;s preview build to see the animations.</p>
      {items.length === 0 ? <p className="text-ui-small text-ui-text-muted">Nothing to preview yet.</p> : (
        <div className="grid gap-s3 md:grid-cols-2">
          {items.map(({ level, index, item }) => {
            const p = item.prompt as { text?: string } | string | undefined;
            const opts = (item.options as unknown[]) ?? (item.cards as unknown[]) ?? [];
            const right = new Set((item.correct as string[]) ?? []);
            return (
              <article key={`${level}-${index}`} className="rounded-md bg-ui-surface p-s4">
                <p className="text-ui-caption text-ui-text-muted">{level ? `${level} · ` : ""}{index + 1} · {kindOf(item.kind)?.label}</p>
                <p className="text-ui-body-strong">{typeof p === "string" ? p : p?.text ?? (item.word as string) ?? (item.sentence as string) ?? ""}</p>
                {opts.length > 0 && (
                  <ul className="mt-s2 flex flex-wrap gap-s2">
                    {opts.map((o, i) => {
                      const id = typeof o === "string" ? o : (o as { id: string }).id;
                      const lab = typeof o === "string" ? o : `${(o as { label?: string }).label ?? ""} ${(o as { picture?: string }).picture ?? ""}`.trim();
                      return <li key={i} className={`rounded-pill px-s3 py-s1 text-ui-small ${right.has(id) ? "bg-ui-success-soft text-ui-success" : "bg-ui-bg"}`}>{right.has(id) ? "✓ " : ""}{lab}</li>;
                    })}
                  </ul>
                )}
                {item.hint ? <p className="mt-s2 text-ui-small text-ui-text-muted">Hint: {String(item.hint)}</p> : null}
              </article>
            );
          })}
        </div>
      )}
    </section>
  );
}
