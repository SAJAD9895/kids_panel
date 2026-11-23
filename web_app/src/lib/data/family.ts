import "server-only";
import type { Db } from "./db";

export type Buddy = { id: string; key: string };
/** The buddies (avatars) a child can pick: original art in the public bucket. */
export async function listBuddies(db: Db): Promise<Buddy[]> {
  const { data, error } = await db.from("avatars").select("id, key, sort").eq("active", true).order("sort");
  if (error) throw new Error(error.message);
  return (data ?? []).map((a) => ({ id: a.id as string, key: a.key as string }));
}
