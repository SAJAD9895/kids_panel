/**
 * Backend integration test against a REAL Supabase (local CLI stack or the development project).
 * Covers what the SQL tests can't: Supabase Auth sessions and JWTs, the Data API (PostgREST)
 * surface, RPC exposure and Storage over HTTP.
 *
 *   KL_INTEGRATION_TARGET=dev \
 *   SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SECRET_KEY=... SUPABASE_DB_URL=... \
 *   deno test -A supabase/tests/integration/backend.integration.test.ts
 *
 * It creates two throwaway families (emails *@example.test) and deletes them afterwards.
 * It refuses to run unless KL_INTEGRATION_TARGET is "local" or "dev": never point it at production.
 * Needs the email provider with password sign-in enabled (Auth → Providers → Email).
 */
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import postgres from "npm:postgres@3.4.5";
import { assert, assertEquals } from "jsr:@std/assert@1.0.13";

const target = Deno.env.get("KL_INTEGRATION_TARGET");
if (target !== "local" && target !== "dev") {
  throw new Error('Set KL_INTEGRATION_TARGET=local or dev. This test must never run against production.');
}
const env = (k: string) => {
  const v = Deno.env.get(k);
  if (!v) throw new Error(`missing env ${k}`);
  return v;
};
const URL_ = env("SUPABASE_URL");
const PUB = env("SUPABASE_PUBLISHABLE_KEY");
const service = createClient(URL_, env("SUPABASE_SECRET_KEY"), { auth: { persistSession: false } });
const sql = postgres(env("SUPABASE_DB_URL"), { prepare: false, max: 1 });

const run = crypto.randomUUID().slice(0, 8);
const password = `It-${crypto.randomUUID()}-Aa1`;
const consents = [
  { type: "terms", policyVersion: "2026-11", method: "checkbox" },
  { type: "privacy_policy", policyVersion: "2026-11", method: "checkbox" },
  { type: "child_data_collection", policyVersion: "2026-11", method: "email_plus" },
];
const anonClient = () => createClient(URL_, PUB, { auth: { persistSession: false, autoRefreshToken: false } });
const jwtPayload = (t: string) => JSON.parse(atob(t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));

type Family = { userId: string; email: string; client: SupabaseClient; childId: string; refresh: string };

async function makeFamily(tag: string, nickname: string): Promise<Family> {
  const email = `it-${run}-${tag}@example.test`;
  const { data, error } = await service.auth.admin.createUser({ email, password, email_confirm: true });
  if (error) throw error;
  const userId = data.user.id;
  // onboarding exactly as the Edge Function will do it: user id from the verified identity, never the body
  const [row] = await sql`select private.onboard_family(${userId}::uuid, ${sql.json({
    timezone: "Europe/London",
    child: { nickname, birthYearMonth: "2021-04" },
    consents,
  })}::jsonb) as r`;
  const client = anonClient();
  const s = await client.auth.signInWithPassword({ email, password });
  if (s.error) throw s.error;
  return { userId, email, client, childId: row.r.childId, refresh: s.data.session!.refresh_token };
}

let A: Family, B: Family;

Deno.test({
  name: "backend integration",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    A = await makeFamily("a", "Ava");
    B = await makeFamily("b", "Ben");
    try {
      await t.step("auth: session JWT has the right subject, role, aal and lifetime", async () => {
        const { data } = await A.client.auth.getSession();
        const p = jwtPayload(data.session!.access_token);
        assertEquals(p.sub, A.userId);
        assertEquals(p.role, "authenticated");
        assertEquals(p.aal, "aal1");
        assert(p.exp - p.iat <= 3600, `JWT lifetime ${p.exp - p.iat}s > 1h`);
        const u = await A.client.auth.getUser();
        assertEquals(u.data.user?.id, A.userId);
      });

      await t.step("RLS over the Data API: own child visible, other family's child invisible", async () => {
        const own = await A.client.from("child_profiles").select("id,nickname");
        assertEquals(own.error, null);
        assertEquals(own.data?.map((r) => r.nickname), ["Ava"]);
        const probe = await B.client.from("child_profiles").select("id").eq("id", A.childId);
        assertEquals(probe.data, []);
        const acc = await B.client.from("parent_accounts").select("owner_user_id");
        assertEquals(acc.data?.length, 1);
        assertEquals(acc.data?.[0].owner_user_id, B.userId);
        const rules = await B.client.from("screen_time_rules").select("child_id").eq("child_id", A.childId);
        assertEquals(rules.data, []);
      });

      await t.step("direct client writes are refused", async () => {
        const w = await A.client.from("child_profiles").update({ nickname: "Hacked" }).eq("id", A.childId).select();
        assert(w.error !== null || (w.data ?? []).length === 0, "client updated a child directly");
        const i = await A.client.from("parent_accounts").insert({ owner_user_id: B.userId });
        assert(i.error !== null, "client inserted an account");
        const r = await A.client.from("admin_user_roles").insert({ user_id: A.userId, role_key: "super_admin" });
        assert(r.error !== null, "parent granted themselves super_admin");
      });

      await t.step("anon sees no family data", async () => {
        const c = anonClient();
        const kids = await c.from("child_profiles").select("id");
        assertEquals(kids.data ?? [], []);
        const subs = await c.from("subscriptions").select("id");
        assertEquals(subs.data ?? [], []);
      });

      await t.step("private functions are not reachable through the Data API", async () => {
        const viaPublic = await A.client.rpc("onboard_family", { p_user_id: A.userId, p: {} });
        assert(viaPublic.error !== null, "onboard_family callable via /rpc");
        const viaPrivate = await A.client.schema("private").rpc("delete_child", { p_user_id: A.userId, p_child_id: A.childId });
        assert(viaPrivate.error !== null, "private schema exposed");
        const stillThere = await A.client.from("child_profiles").select("id").eq("id", A.childId);
        assertEquals(stillThere.data?.length, 1);
      });

      await t.step("storage: private buckets unreadable, signed URLs work, admin-staging closed to parents", async () => {
        const path = `it/${run}/probe.json`;
        const up = await service.storage.from("content").upload(path, new Blob(['{"ok":true}'], { type: "application/json" }));
        assertEquals(up.error, null);
        try {
          const direct = await A.client.storage.from("content").download(path);
          assert(direct.error !== null, "parent downloaded private content without a signed URL");
          const list = await A.client.storage.from("content").list(`it/${run}`);
          assertEquals(list.data ?? [], []);
          const signed = await service.storage.from("content").createSignedUrl(path, 60);
          const res = await fetch(signed.data!.signedUrl);
          assertEquals(res.status, 200);
          await res.body?.cancel();
          const parentUpload = await A.client.storage.from("admin-staging").upload(`${A.userId}/x.json`, new Blob(["{}"]));
          assert(parentUpload.error !== null, "parent uploaded to admin-staging");
          const pubList = await anonClient().storage.from("public-assets").list();
          assertEquals(pubList.data ?? [], []);
        } finally {
          await service.storage.from("content").remove([path]);
        }
      });

      await t.step("refresh token rotation: a used refresh token can't be replayed", async () => {
        const first = await A.client.auth.refreshSession();
        assertEquals(first.error, null);
        assert(first.data.session!.refresh_token !== A.refresh);
        await new Promise((r) => setTimeout(r, 11_000)); // past the 10 s reuse interval
        const replay = await anonClient().auth.refreshSession({ refresh_token: A.refresh });
        assert(replay.error !== null, "old refresh token was accepted after rotation");
      });

      await t.step("sign-out (global) revokes the refresh token", async () => {
        const { data } = await B.client.auth.getSession();
        const rt = data.session!.refresh_token;
        await B.client.auth.signOut({ scope: "global" });
        const again = await anonClient().auth.refreshSession({ refresh_token: rt });
        assert(again.error !== null, "refresh token still valid after sign-out");
      });
    } finally {
      // cleanup: family rows (cascade), then the auth users
      await sql`delete from public.parent_accounts where owner_user_id in (${A.userId}::uuid, ${B.userId}::uuid)`;
      await service.auth.admin.deleteUser(A.userId);
      await service.auth.admin.deleteUser(B.userId);
      await sql.end();
    }
  },
});
