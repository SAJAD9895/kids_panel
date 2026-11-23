// The child zone's play reports: POST /api/play/sync and /api/play/heartbeat. They forward to the
// play Edge Function with the parent's session (cookie → JWT, server-side). The child is the one
// chosen in this browser (cookie), never a client-supplied id; apply_session checks the household.
// A route handler (not a server action) so a page that is closing can still send with keepalive.
import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { z } from "zod";
import { callEdge, EdgeError } from "@/lib/edge";
import { CHILD_COOKIE } from "@/lib/session";
import { supabaseServer } from "@/lib/supabase/server";

const session = z.object({
  id: z.string().uuid(), activityId: z.string().uuid(), lessonStepId: z.string().uuid().nullish(),
  source: z.enum(["feed", "search", "collection", "course", "favorite", "shuffle", "together", "learning_path"]),
  contentVersion: z.number().int().positive(), status: z.enum(["started", "completed", "abandoned"]),
  startedAt: z.string(), endedAt: z.string().nullish(),
});
const syncBody = z.object({
  session, result: z.record(z.unknown()).nullish(),
  responses: z.array(z.record(z.unknown())).max(200).optional(),
});
const heartbeatBody = z.object({ section: z.enum(["watch", "listen"]), seconds: z.number().int().min(1).max(120) });

export async function POST(req: NextRequest, { params }: { params: Promise<{ route: string }> }) {
  const { route } = await params;
  const childId = (await cookies()).get(CHILD_COOKIE)?.value;
  if (!childId) return NextResponse.json({ type: "UNAUTHORIZED" }, { status: 401 });
  // The chosen child must be one of this parent's (RLS shows only their own household); the
  // server checks again in apply_session, this just refuses early and plainly.
  const db = await supabaseServer();
  const { data: mine } = await db.from("child_profiles").select("id").eq("id", childId).maybeSingle();
  if (!mine) return NextResponse.json({ type: "FORBIDDEN" }, { status: 403 });
  try {
    const raw = await req.json();
    if (route === "sync") {
      const b = syncBody.parse(raw);
      const out = await callEdge<{ results: unknown[] }>("play/sync", { body: {
        clockOffsetMs: 0,
        items: [{ session: { ...b.session, childId, platform: "web", appVersion: "web-1" }, result: b.result ?? null, responses: b.responses }],
      } });
      const res = (out.results[0] ?? {}) as { status?: string; reason?: string };
      // a refused item (wrong household, unknown activity…) is an error for the browser
      if (res.status === "rejected") return NextResponse.json({ type: res.reason ?? "VALIDATION", ...res }, { status: res.reason === "NOT_FOUND" ? 404 : 422 });
      return NextResponse.json(res);
    }
    if (route === "heartbeat") {
      const b = heartbeatBody.parse(raw);
      return NextResponse.json(await callEdge("play/heartbeat", { body: { childId, ...b } }));
    }
    return NextResponse.json({ type: "NOT_FOUND" }, { status: 404 });
  } catch (e) {
    if (e instanceof z.ZodError) return NextResponse.json({ type: "VALIDATION", detail: e.issues[0]?.message }, { status: 400 });
    if (e instanceof EdgeError) return NextResponse.json({ type: e.type, detail: e.detail }, { status: e.status });
    throw e;
  }
}
