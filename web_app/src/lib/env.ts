// Public configuration only. The web app never holds the Supabase service role key or a
// database URL: every read and write runs as the signed-in parent, under RLS (docs/web/architecture.md).
export const env = {
  url: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  key: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "",
};

/** Problems with the configuration; the app refuses to start with any. */
export function configProblems(e = env): string[] {
  const out: string[] = [];
  if (!e.url) out.push("NEXT_PUBLIC_SUPABASE_URL is missing");
  if (!e.key) out.push("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is missing");
  if (e.key.startsWith("sb_secret_")) out.push("the key is a SECRET key; use the publishable key");
  const parts = e.key.split(".");
  if (parts.length === 3) {
    try {
      const role = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")).role;
      if (role === "service_role") out.push("the key is the SERVICE ROLE key; use the anon / publishable key");
    } catch {
      /* not a JWT: fine */
    }
  }
  return out;
}
