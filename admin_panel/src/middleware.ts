// Refreshes the Supabase session cookie on every request and sends signed-out visitors to
// /login. Pages still check the admin, MFA level and permissions themselves (lib/auth.ts);
// the database checks them again on every query.
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { env } from "./lib/env";

export async function middleware(req: NextRequest) {
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
  const { data } = await db.auth.getUser();
  const open = req.nextUrl.pathname.startsWith("/login") || req.nextUrl.pathname.startsWith("/no-access");
  if (!data.user && !open) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    url.search = "";
    return NextResponse.redirect(url);
  }
  return res;
}

export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico|api/health).*)"] };
