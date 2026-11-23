"use client";
import { createBrowserClient } from "@supabase/ssr";
import { env } from "../env";

/** Browser client: sign-in, sign-up and the child zone (calls Edge Functions with the parent's session). */
export const supabaseBrowser = () => createBrowserClient(env.url, env.key);
