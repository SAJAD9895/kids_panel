// Form values ⇄ games.config items (the engine's format). Pure functions, unit-tested.
import { kindOf } from "./kinds";

export type Item = Record<string, unknown> & { kind: string };
export type Level = { id: string; label?: string; minAgeMonths?: number; options?: number; attempts?: number; items: Item[] };
export type GameConfig = { intro?: { text?: string; speak?: string } | string; items?: Item[]; levels?: Level[] };

const nonEmpty = (s: string) => s.trim().length > 0;
const lines = (v: string) => v.split("\n").map((s) => s.trim()).filter(nonEmpty);

/** "Cat | icon:cat" → {id, label, picture}; "Cat" → "Cat". */
function choice(line: string, i: number): string | { id: string; label?: string; picture?: string } {
  const [label, picture] = line.split("|").map((s) => s.trim());
  if (!picture) return label;
  return { id: `o${i + 1}`, ...(label ? { label } : {}), picture };
}
const choiceLabel = (c: unknown) => (typeof c === "string" ? c : String((c as { label?: string; id?: string }).label ?? (c as { id?: string }).id ?? ""));
const choiceLine = (c: unknown) => (typeof c === "string" ? c : `${(c as { label?: string }).label ?? ""} | ${(c as { picture?: string }).picture ?? ""}`.trim());

/** Builds one item from the form's raw strings. Unknown or empty fields are left out. */
export function itemFromForm(kind: string, raw: Record<string, string>): Item {
  const k = kindOf(kind);
  if (!k) throw new Error(`unknown kind ${kind}`);
  const item: Item = { kind };
  const options: unknown[] = [];
  for (const f of k.fields) {
    const v = (raw[f.name] ?? "").trim();
    if (!v && f.type !== "bool") continue;
    switch (f.type) {
      case "text":
        if (f.name === "prompt") item.prompt = { text: v, speak: v };
        else item[f.name] = v;
        break;
      case "int": item[f.name] = Number.parseInt(v, 10); break;
      case "enum": item[f.name] = v; break;
      case "bool": if (v === "on" || v === "true") item[f.name] = true; break;
      case "picture": item[f.name] = v; break;
      case "letters": item[f.name] = lines(v.replace(/[,\s]+/g, "\n")); break;
      case "choices": {
        const list = lines(v).map(choice);
        item[f.name] = list;
        if (f.name === "options") options.push(...list);
        break;
      }
      case "answers": {
        // the engine's `correct` names option ids or labels
        const want = lines(v).map((s) => s.toLowerCase());
        item.correct = options
          .filter((o) => want.includes(choiceLabel(o).toLowerCase()))
          .map((o) => (typeof o === "string" ? o : (o as { id: string }).id));
        break;
      }
      case "pairs": {
        const pairs = lines(v).map((l) => l.split("=").map((s) => s.trim()));
        if (f.name === "solution") item.solution = Object.fromEntries(pairs.filter((p) => p.length === 2));
        else item.pairs = pairs.filter((p) => p.length === 2).map(([l, r]) => ({ left: { label: l }, right: { label: r } }));
        break;
      }
      case "bins":
        item.items = lines(v).map((l) => {
          const [left, bin] = l.split("=").map((s) => s.trim());
          const [label, picture] = left.split("|").map((s) => s.trim());
          return { ...(label ? { label } : {}), ...(picture ? { picture } : {}), bin };
        });
        break;
      case "json": item[f.name] = JSON.parse(v); break;
    }
  }
  if (item.kind === "letter_recognition" && typeof item.target === "string") item.target = item.target.slice(0, 1);
  return item;
}

/** The form's raw strings for an existing item (so it can be edited). */
export function formFromItem(item: Item): Record<string, string> {
  const k = kindOf(item.kind);
  const out: Record<string, string> = {};
  if (!k) return out;
  for (const f of k.fields) {
    const v = item[f.name];
    if (v === undefined) continue;
    switch (f.type) {
      case "text": out[f.name] = f.name === "prompt" ? String((v as { text?: string }).text ?? v) : String(v); break;
      case "int": case "enum": case "picture": out[f.name] = String(v); break;
      case "bool": out[f.name] = v ? "on" : ""; break;
      case "letters": out[f.name] = (v as string[]).join(" "); break;
      case "choices": out[f.name] = (v as unknown[]).map(choiceLine).join("\n"); break;
      case "answers": {
        const opts = (item.options as unknown[]) ?? [];
        out.correct = (v as string[]).map((id) => {
          const o = opts.find((x) => (typeof x === "string" ? x === id : (x as { id: string }).id === id));
          return o === undefined ? id : choiceLabel(o);
        }).join("\n");
        break;
      }
      case "pairs":
        out[f.name] = f.name === "solution"
          ? Object.entries(v as Record<string, string>).map(([a, b]) => `${a} = ${b}`).join("\n")
          : (v as { left: { label?: string }; right: { label?: string } }[]).map((p) => `${p.left.label ?? ""} = ${p.right.label ?? ""}`).join("\n");
        break;
      case "bins":
        out.items = (v as { label?: string; picture?: string; bin: string }[])
          .map((x) => `${x.label ?? ""}${x.picture ? ` | ${x.picture}` : ""} = ${x.bin}`).join("\n");
        break;
      case "json": out[f.name] = JSON.stringify(v); break;
    }
  }
  return out;
}

/** One line a reviewer can read ("Multiple choice · Which is red? · 3 options · answer: Apple"). */
export function describe(item: Item): string {
  const k = kindOf(item.kind);
  const parts = [k?.label ?? item.kind];
  const p = item.prompt as { text?: string } | string | undefined;
  const q = typeof p === "string" ? p : p?.text;
  if (q) parts.push(q);
  if (Array.isArray(item.options)) {
    parts.push(`${item.options.length} options`);
    const right = ((item.correct as string[]) ?? []).map((id) => {
      const o = (item.options as unknown[]).find((x) => (typeof x === "string" ? x === id : (x as { id: string }).id === id));
      return o === undefined ? id : choiceLabel(o);
    });
    if (right.length) parts.push(`answer: ${right.join(", ")}`);
  }
  for (const f of ["word", "target", "glyph", "shape", "sentence"]) if (item[f] !== undefined) parts.push(`${f}: ${item[f]}`);
  if (item.a !== undefined) parts.push(`${item.a} ${item.op ?? "+"} ${item.b}`);
  if (Array.isArray(item.pairs)) parts.push(`${item.pairs.length} pairs`);
  if (Array.isArray(item.cards)) parts.push(`${item.cards.length} card faces`);
  if (Array.isArray(item.bins)) parts.push(`${item.bins.length} groups, ${(item.items as unknown[])?.length ?? 0} things`);
  if (item.hint) parts.push("has a hint");
  return parts.join(" · ");
}

/** Every item in the config, with its level. */
export function allItems(c: GameConfig): { level: string | null; index: number; item: Item }[] {
  if (Array.isArray(c.levels) && c.levels.length) {
    return c.levels.flatMap((l) => l.items.map((item, index) => ({ level: l.id, index, item })));
  }
  return (c.items ?? []).map((item, index) => ({ level: null, index, item }));
}
