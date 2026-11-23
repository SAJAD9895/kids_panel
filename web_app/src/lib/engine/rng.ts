/**
 * Deterministic seeded random (port of Dart `SeededRandom` and `stableHash` in item_spec.dart),
 * so a resumed session shows the same order.
 *
 * This reproduces Dart's sequence bit for bit: the LCG step `state * 1103515245 + 12345` is
 * masked to 31 bits, and the low 31 bits of the product are exact with `Math.imul`. So the web
 * app shuffles options, tiles and cards exactly like the Flutter app for the same session id.
 */

export class SeededRandom {
  private state: number;

  constructor(seed: number) {
    this.state = (seed & 0x7fffffff) | 1;
  }

  nextInt(max: number): number {
    this.state = (Math.imul(this.state, 1103515245) + 12345) & 0x7fffffff;
    return this.state % max;
  }

  shuffled<T>(items: readonly T[]): T[] {
    const out = [...items];
    for (let i = out.length - 1; i > 0; i--) {
      const j = this.nextInt(i + 1);
      const t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return out;
  }
}

/** Dart `stableHash`: a 31-bit string hash over UTF-16 code units. */
export function stableHash(s: string): number {
  let h = 17;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0x7fffffff;
  return h;
}
