/** Shared by the engine tests: the repo's seeded game configs and fixtures. */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { JsonMap } from "@/lib/engine";

export const here = (p: string) => fileURLToPath(new URL(p, import.meta.url));

/** Every `update games set config = '…'::jsonb -- engine:<slug>` row of supabase/seed.sql. */
export function seedConfigs(): Record<string, JsonMap> {
  const seed = readFileSync(here("../../../supabase/seed.sql"), "utf8");
  const out: Record<string, JsonMap> = {};
  for (const m of seed.matchAll(/update games set config = '(.*)'::jsonb -- engine:([a-z0-9-]+)/g)) {
    out[m[2]] = JSON.parse(m[1].replace(/''/g, "'")) as JsonMap;
  }
  return out;
}

/** The admin CMS game with every kind (kids_app/test/fixtures/admin_cms/every_kind.json). */
export function everyKindConfig(): JsonMap {
  return JSON.parse(readFileSync(here("../../../kids_app/test/fixtures/admin_cms/every_kind.json"), "utf8")) as JsonMap;
}

/** The `engine-sampler` config: one item of every kind (lib/demo/demo_activity_content.dart). */
export function samplerItems(): JsonMap[] {
  return seedConfigs()["engine-sampler"].items as JsonMap[];
}
