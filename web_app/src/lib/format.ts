/** Localized text from a jsonb `{en: "…"}` (English is the only content locale so far). */
export const t = (v: unknown, fallback = ""): string => {
  if (typeof v === "string") return v;
  if (v && typeof v === "object") {
    const o = v as Record<string, unknown>;
    return String(o.en ?? Object.values(o)[0] ?? fallback);
  }
  return fallback;
};
export const minutes = (secs: number) => (secs < 60 ? `${secs} s` : `${Math.round(secs / 60)} min`);
export const clock = (ms: number) => {
  const s = Math.max(0, Math.floor(ms / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
};
export const ageYears = (birthYearMonth: string, now = new Date()) => {
  const [y, m] = birthYearMonth.split("-").map(Number);
  return Math.floor((now.getUTCFullYear() * 12 + now.getUTCMonth() + 1 - (y * 12 + m)) / 12);
};
export const ageMonths = (birthYearMonth: string, now = new Date()) => {
  const [y, m] = birthYearMonth.split("-").map(Number);
  return now.getUTCFullYear() * 12 + now.getUTCMonth() + 1 - (y * 12 + m);
};
export const day = (iso: string | null | undefined, tz?: string) =>
  iso ? new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: tz }).format(new Date(iso)) : "—";
export const dayTime = (iso: string | null | undefined, tz?: string) =>
  iso ? new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", timeZone: tz }).format(new Date(iso)) : "—";
/** Today's date (YYYY-MM-DD) in the household's time zone: the day stars and goals count on. */
export const localDate = (tz: string, at = new Date()) =>
  new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" }).format(at);
