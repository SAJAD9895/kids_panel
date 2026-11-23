// Refreshes the Supabase session cookie on every request and sends signed-out visitors away
// from the child zone and the grown-up pages. Pages check the family, the chosen child and the
// parental gate themselves (lib/session.ts); the database checks every read again (RLS).
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { env } from "./lib/env";
import { verifiedUser } from "./lib/supabase/claims";

const PROTECTED = ["/kids", "/who", "/parents", "/gate", "/sign-up/family"];

export async function middleware(req: NextRequest) {
  // The path, for pages that send the visitor back here after the parental gate or sign-in.
  req.headers.set("x-pathname", req.nextUrl.pathname + req.nextUrl.search);
  let res = NextResponse.next({ request: req });
  const db = createServerClient(env.url, env.key, {
    cookies: {
      getAll: () => req.cookies.getAll(),
      setAll: (list) => {
        list.forEach(({ name, value }) => req.cookies.set(name, value));
        res = NextResponse.next({ request: req });
        list.forEach(({ name, value, options }) => res.cookies.set(name, value, options));
      },
    },
  });
  // Verified locally against the project's public keys: no Auth round trip per request.
  const user = await verifiedUser(db);
  const path = req.nextUrl.pathname;
  if (!user && PROTECTED.some((p) => path === p || path.startsWith(`${p}/`))) {
    const url = req.nextUrl.clone();
    url.pathname = "/sign-in";
    url.search = `?next=${encodeURIComponent(path)}`;
    return NextResponse.redirect(url);
  }
  return res;
}

export const config = { matcher: ["/((?!_next/|fonts/|favicon|api/health).*)"] };
