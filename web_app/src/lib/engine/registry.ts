/**
 * The known activity types (port of registry.dart). `standardRegistry()` has the same 16 keys
 * as `KindRegistry.standard()`.
 */
import { dartStr, textIsEmpty } from "./common";
import { arrangeKinds } from "./kinds/arrange";
import { choiceKinds } from "./kinds/choice";
import { memoryKind, traceKind } from "./kinds/memory-trace";
import type { ActivityKind, Hint, ItemAnswer, ItemSpec, JsonMap, ParseContext, Verdict } from "./types";
import { ALL_KINDS, ContentError, noHint } from "./types";

export class KindRegistry {
  private readonly kinds = new Map<string, ActivityKind<ItemSpec>>();

  constructor(kinds: Iterable<ActivityKind<ItemSpec>> = []) {
    for (const k of kinds) this.register(k);
  }

  register(kind: ActivityKind<ItemSpec>): void {
    this.kinds.set(kind.key, kind);
  }

  supports(key: string): boolean {
    return this.kinds.has(key);
  }

  get keys(): string[] {
    return [...this.kinds.keys()];
  }

  kindOf(spec: ItemSpec): ActivityKind<ItemSpec> {
    const k = this.kinds.get(spec.kind);
    if (!k) throw new ContentError(`unknown kind ${spec.kind}`);
    return k;
  }

  /** Reads one item; throws ContentError for unknown kinds or bad content. */
  parseItem(json: JsonMap, ctx: ParseContext): ItemSpec {
    const key = json.kind;
    const kind = typeof key === "string" ? this.kinds.get(key) : undefined;
    if (!kind) throw new ContentError(`unknown kind ${dartStr(key)}`);
    try {
      return kind.parse(json, ctx);
    } catch (e) {
      if (e instanceof ContentError) throw e;
      throw new ContentError(`bad ${dartStr(key)} item ${ctx.itemId}: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  evaluate(spec: ItemSpec, answer: ItemAnswer): Verdict {
    return this.kindOf(spec).evaluate(spec, answer);
  }

  hint(spec: ItemSpec, level: number): Hint {
    return this.kindOf(spec).hint(spec, level);
  }

  solution(spec: ItemSpec): ItemAnswer | null {
    return this.kindOf(spec).solution(spec);
  }
}

/** The default hint for a kind that has nothing special (Dart `ActivityKind.hint`). */
export function defaultHint(spec: ItemSpec, level: number): Hint {
  return level === 1 && !textIsEmpty(spec.hintText) ? { text: spec.hintText, eliminate: [], reveal: [] } : noHint;
}

/** Every type built into the app, in KindRegistry.standard() order. */
export function standardRegistry(): KindRegistry {
  const all = [...choiceKinds, ...arrangeKinds, memoryKind, traceKind] as ActivityKind<ItemSpec>[];
  return new KindRegistry(ALL_KINDS.map((k) => all.find((x) => x.key === k)!));
}

