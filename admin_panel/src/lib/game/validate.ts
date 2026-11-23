// The engine's own JSON Schema (supabase/schemas/game-config.schema.json, copied by
// scripts/sync-tokens.mjs). A config that passes is one the Flutter app accepts.
import Ajv2020 from "ajv/dist/2020";
import schema from "./game-config.schema.json";

const ajv = new Ajv2020({ allErrors: true, strict: false });
const check = ajv.compile(schema);

export type ConfigProblem = { path: string; message: string };

export function validateConfig(config: unknown): ConfigProblem[] {
  if (check(config)) {
    // beyond the schema: the engine needs at least one item to play
    const c = config as { items?: unknown[]; levels?: { id: string; items: unknown[] }[] };
    const n = (c.items?.length ?? 0) + (c.levels ?? []).reduce((s, l) => s + l.items.length, 0);
    const ids = (c.levels ?? []).map((l) => l.id);
    const out: ConfigProblem[] = [];
    if (n === 0) out.push({ path: "/", message: "add at least one item" });
    if (new Set(ids).size !== ids.length) out.push({ path: "/levels", message: "level ids must be different" });
    return out;
  }
  // keep the most useful messages (if/then schemas repeat themselves)
  const seen = new Set<string>();
  return (check.errors ?? [])
    .filter((e) => e.keyword !== "if" && e.keyword !== "anyOf" && e.keyword !== "oneOf")
    .map((e) => ({ path: e.instancePath || "/", message: e.message ?? "is not valid" }))
    .filter((p) => (seen.has(p.path + p.message) ? false : (seen.add(p.path + p.message), true)));
}
