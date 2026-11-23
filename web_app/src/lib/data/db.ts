import type { supabaseServer } from "../supabase/server";
export type Db = Awaited<ReturnType<typeof supabaseServer>>;
