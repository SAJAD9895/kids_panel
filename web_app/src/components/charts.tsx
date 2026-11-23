// Bar charts drawn with HTML and the chart tokens. Every chart has a one-line summary for screen
// readers and a "Show as a table" view with the exact numbers.
import type { ReactNode } from "react";

export type Bar = { label: string; value: number; note?: string; highlight?: boolean };

export function BarChart({ title, summary, bars, max, unit = "", format = (v: number) => `${v}${unit}`, children }: {
  title: string; summary: string; bars: Bar[]; max?: number; unit?: string; format?: (v: number) => string; children?: ReactNode;
}) {
  const top = Math.max(1, max ?? Math.max(...bars.map((b) => b.value), 0));
  return (
    <figure className="flex flex-col gap-s3" aria-label={title}>
      <figcaption className="flex flex-col gap-s1"><span className="text-ui-h3">{title}</span><span className="text-ui-small text-ui-text-muted">{summary}</span></figcaption>
      <div className="flex h-ui-chart-h items-end gap-s2 border-b border-ui-border" aria-hidden>
        {bars.map((b) => (
          <div key={b.label} className="flex min-w-0 flex-1 flex-col items-center justify-end gap-s1 self-stretch">
            <span className="text-ui-caption tabular-nums text-ui-text-muted">{b.value ? format(b.value) : ""}</span>
            <span className={`w-full rounded-t-sm ${b.highlight ? "bg-ui-chart-1" : "bg-ui-chart-2"}`} style={{ height: `${(b.value / top) * 100}%`, minHeight: b.value ? "2%" : 0 }} />
          </div>
        ))}
      </div>
      <div className="flex gap-s2" aria-hidden>{bars.map((b) => <span key={b.label} className="min-w-0 flex-1 truncate text-center text-ui-caption text-ui-text-muted">{b.label}</span>)}</div>
      <details>
        <summary className="cursor-pointer text-ui-small text-ui-primary">Show as a table</summary>
        <table className="mt-s2 w-full text-ui-small">
          <thead><tr><th className="py-s1 text-left">Item</th><th className="py-s1 text-right">Value</th><th className="py-s1 text-left">Note</th></tr></thead>
          <tbody>{bars.map((b) => <tr key={b.label} className="border-t border-ui-border"><td className="py-s1">{b.label}</td><td className="py-s1 text-right tabular-nums">{format(b.value)}</td><td className="py-s1">{b.note ?? ""}</td></tr>)}</tbody>
        </table>
      </details>
      {children}
    </figure>
  );
}
