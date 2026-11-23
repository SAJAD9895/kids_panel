// Magic links (PKCE): Supabase sends the parent back here with a one-time code, exchanged for a
// session on the server. Only local paths are accepted as the next page.
import { NextResponse, type NextRequest } from "next/server";
import { supabaseServer } from "@/lib/supabase/server";
import { GATE_COOKIE, GATE_MINUTES } from "@/lib/session";

export async function GET(req: NextRequest) {
  const code = req.nextUrl.searchParams.get("code");
  const next = req.nextUrl.searchParams.get("next") ?? "/who";
  const safe = next.startsWith("/") && !next.startsWith("//") ? next : "/who";
  if (code) {
    const db = await supabaseServer();
    const { error } = await db.auth.exchangeCodeForSession(code);
    if (!error) {
      // same as signing in with the code: the parent just proved who they are, so open the gate
      const res = NextResponse.redirect(new URL(safe, req.url));
      res.cookies.set(GATE_COOKIE, String(Date.now() + GATE_MINUTES * 60_000), { httpOnly: true, sameSite: "lax", secure: process.env.NODE_ENV === "production", path: "/", maxAge: GATE_MINUTES * 60 });
      return res;
    }
  }
  return NextResponse.redirect(new URL("/sign-in?link=expired", req.url));
}
