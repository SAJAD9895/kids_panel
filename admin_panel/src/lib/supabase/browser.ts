"use client";
import { createBrowserClient } from "@supabase/ssr";
import { env } from "../env";

/** Browser client: sign-in, MFA, and uploads to the admin's own staging folder. */
export const supabaseBrowser = () => createBrowserClient(env.url, env.key);
