// POST /play/sync (docs/architecture/07-api-specification.md): uploads finished, abandoned or
// started sessions, live or saved while offline. Each item runs private.apply_session in its own
// transaction, so one bad item never blocks the rest. Idempotent per session id.
//
// POST /play/launch (Phase 11): the gate before playing — published, age, Plus, the parent's section
// switches and blocked categories, the daily limit (private.launch) — then signed URLs for the media.
// POST /play/heartbeat (Phase 11): adds watched / listened seconds; returns what's left today.
import { HttpError, json, readJson, routeParts, serve } from "../_shared/http.ts";
import { signAll } from "../_shared/storage.ts";
import { requireUser } from "../_shared/auth.ts";
import { db, jsonb } from "../_shared/db.ts";
import { parse, uuid, z } from "../_shared/validate.ts";

const iso = z.string().datetime({ offset: true });

const item = z.object({
  session: z.object({
    id: uuid,
    childId: uuid,
    activityId: uuid,
    lessonStepId: uuid.nullish(),
    source: z.enum(["feed", "search", "collection", "course", "favorite", "shuffle", "together", "learning_path", "offline"]),
    platform: z.enum(["ios", "android", "web"]),
    appVersion: z.string().max(32),
    contentVersion: z.number().int().positive().max(100000),
    status: z.enum(["started", "completed", "abandoned"]),
    startedAt: iso,
    endedAt: iso.nullish(),
  }),
  result: z.object({
    completed: z.boolean(),
    score: z.number().min(0).max(100).nullish(),
    correctCount: z.number().int().min(0).max(1000).nullish(),
    totalCount: z.number().int().min(0).max(1000).nullish(),
    durationMs: z.number().int().min(0).max(4 * 3600 * 1000),
    metrics: z.record(z.unknown()).optional(),
  }).nullish(),
  responses: z.array(z.object({
    questionId: uuid,
    attempt: z.number().int().min(1).max(20),
    answerId: uuid.nullish(),
    isCorrect: z.boolean(),
    responseMs: z.number().int().min(0).max(3600 * 1000).nullish(),
  })).max(200).optional(),
});

const body = z.object({
  deviceId: z.string().max(64).optional(),
  clockOffsetMs: z.number().int().min(-86_400_000).max(86_400_000).optional(),
  items: z.array(item).min(1).max(100),
});

const launchBody = z.object({
  childId: uuid,
  activityId: uuid,
  source: z.enum(["feed", "search", "collection", "course", "favorite", "shuffle", "together", "learning_path", "offline"]).optional(),
}).strict();

const heartbeatBody = z.object({
  childId: uuid,
  section: z.enum(["games", "learn", "watch", "listen", "together"]),
  seconds: z.number().int().min(1).max(120),
}).strict();

type LaunchAsset = { role: string; bucket: string; path: string; durationMs?: number | null; [k: string]: unknown };

serve(async (req) => {
  const [route] = routeParts(req, "play");
  if (req.method !== "POST") throw new HttpError("NOT_FOUND");
  if (route === "launch") {
    const caller = await requireUser(req);
    const input = parse(launchBody, await readJson(req));
    const [row] = await db()`select private.launch(${caller.userId}::uuid, ${db().json(input)}::jsonb) as r`;
    const r = row.r as { assets: LaunchAsset[] } & Record<string, unknown>;
    return json({ ...r, assets: await signAll(r.assets) });
  }
  if (route === "heartbeat") {
    const caller = await requireUser(req);
    const input = parse(heartbeatBody, await readJson(req));
    const [row] = await db()`
      select private.add_screen_time(${caller.userId}::uuid, ${input.childId}::uuid, ${input.section}, ${input.seconds}) as r`;
    return json(row.r);
  }
  if (route !== "sync") throw new HttpError("NOT_FOUND");
  const caller = await requireUser(req);
  const input = parse(body, await readJson(req));
  if (JSON.stringify(input).length > 512_000) throw new HttpError("VALIDATION", "payload too large");

  const results = [];
  for (const it of input.items) {
    try {
      const [row] = await db()`
        select private.apply_session(${caller.userId}::uuid,
          ${jsonb({ ...it, clockOffsetMs: input.clockOffsetMs ?? 0 })}::jsonb) as r`;
      results.push(row.r);
    } catch (err) {
      const code = (err as { code?: string }).code ?? "";
      // Client errors are reported per item; anything else is a server problem for the whole call.
      if (!code.startsWith("KL")) throw err;
      results.push({ sessionId: it.session.id, status: "rejected", reason: (err as { message?: string }).message });
    }
  }
  return json({ results });
});
