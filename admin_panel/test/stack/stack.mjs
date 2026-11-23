// LOCAL TEST ONLY. A stand-in for a Supabase project, for the admin CMS's integration and
// end-to-end tests (there's no Docker or Supabase CLI here):
//   Postgres 17   every migration + seed.sql + seed_admins.sql (the real schema, RLS and functions)
//   PostgREST 16  the real Data API, schemas public + admin_api, JWTs checked with a local secret
//   gateway       /rest/v1 → PostgREST; /auth/v1 password sign-in, TOTP challenge/verify/enrol
//                 (code 123456); /storage/v1 upload/download/remove backed by storage.objects (the
//                 real RLS policies and bucket limits) and a temp folder; /functions/v1/admin → Deno
//   Deno          the real supabase/functions/admin Edge Function
// Never point this at real data. Passwords and codes are fixed test values.
import { spawn, execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, readdirSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { randomUUID } from "node:crypto";
import { SignJWT, jwtVerify } from "jose";
import pg from "pg";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..", "..");
const PG_BIN = process.env.PG_BIN ?? "/opt/homebrew/opt/postgresql@17/bin";
export const PASSWORD = "Admin-pass-123";
export const CODE = "123456";
const SECRET = "local-test-jwt-secret-at-least-32-characters-long";
const key = new TextEncoder().encode(SECRET);
const free = () => 20000 + Math.floor(Math.random() * 20000);

const sign = (claims, ttl = 3600) =>
  new SignJWT(claims).setProtectedHeader({ alg: "HS256", typ: "JWT" }).setIssuedAt().setExpirationTime(Math.floor(Date.now() / 1000) + ttl).sign(key);

function waitFor(url, ms = 30000) {
  const end = Date.now() + ms;
  return new Promise((ok, no) => {
    const tick = async () => {
      try { const r = await fetch(url); if (r.status < 500) return ok(); } catch { /* not yet */ }
      if (Date.now() > end) return no(new Error(`timeout waiting for ${url}`));
      setTimeout(tick, 200);
    };
    tick();
  });
}

export async function startStack({ quiet = !process.env.STACK_LOGS } = {}) {
  const tmp = mkdtempSync(join(tmpdir(), "kl-admin-stack-"));
  const procs = [];
  const log = (p, name) => { if (!quiet) { p.stdout?.on("data", (d) => process.stdout.write(`[${name}] ${d}`)); p.stderr?.on("data", (d) => process.stderr.write(`[${name}] ${d}`)); } };

  // ---- Postgres
  const pgPort = free();
  execFileSync(`${PG_BIN}/initdb`, ["-D", join(tmp, "db"), "-U", "postgres", "-A", "trust"], { stdio: "ignore" });
  execFileSync(`${PG_BIN}/pg_ctl`, ["-D", join(tmp, "db"), "-o", `-p ${pgPort} -k '' -c listen_addresses=localhost`, "-l", join(tmp, "pg.log"), "-w", "start"], { stdio: "ignore" });
  const psql = (args) => execFileSync(`${PG_BIN}/psql`, ["-h", "localhost", "-p", String(pgPort), "-U", "postgres", "-X", "-q", "-v", "ON_ERROR_STOP=1", ...args], { stdio: "ignore" });
  psql(["-c", "create database kl"]);
  const files = [join(root, "supabase/tests/local/00_supabase_stub.sql"),
    ...readdirSync(join(root, "supabase/migrations")).sort().map((f) => join(root, "supabase/migrations", f)),
    join(root, "supabase/seed.sql"), join(here, "seed_admins.sql")];
  for (const f of files) psql(["-d", "kl", "-f", f]);
  const dbUrl = `postgres://postgres@localhost:${pgPort}/kl`;
  const pool = new pg.Pool({ connectionString: dbUrl, max: 4 });

  // ---- PostgREST
  const restPort = free();
  writeFileSync(join(tmp, "postgrest.conf"), [
    `db-uri = "postgres://authenticator@localhost:${pgPort}/kl"`,
    `db-schemas = "public,admin_api"`, `db-anon-role = "anon"`, `jwt-secret = "${SECRET}"`,
    `server-port = ${restPort}`, `server-host = "127.0.0.1"`, `db-pool = 5`, `log-level = "crit"`,
  ].join("\n"));
  const rest = spawn("postgrest", [join(tmp, "postgrest.conf")]); procs.push(rest); log(rest, "rest");
  await waitFor(`http://127.0.0.1:${restPort}/`);

  // ---- keys
  const anonKey = await sign({ role: "anon", iss: "local" }, 86400 * 365);
  const serviceKey = await sign({ role: "service_role", iss: "local" }, 86400 * 365);

  // ---- the gateway
  const gwPort = free();
  const url = `http://localhost:${gwPort}`;
  const edgePort = free();
  const factors = new Map(); // userId → [{id, status}]
  const ADMIN_IDS = ["1", "2", "3", "4", "5", "6", "8"].map((n) => `00000000-0000-4000-c000-00000000000${n}`);
  for (const id of ADMIN_IDS) factors.set(id, [{ id: randomUUID(), status: "verified" }]);
  const refresh = new Map(); // refresh token → {userId, amr}
  const files_ = join(tmp, "storage");

  const userRow = async (where, v) => (await pool.query(`select id, email from auth.users where ${where} = $1`, [v])).rows[0];
  const userJson = (u) => ({
    id: u.id, aud: "authenticated", role: "authenticated", email: u.email, email_confirmed_at: new Date().toISOString(),
    app_metadata: { provider: "email" }, user_metadata: {}, created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    factors: (factors.get(u.id) ?? []).map((f) => ({ id: f.id, friendly_name: "Authenticator", factor_type: "totp", status: f.status, created_at: new Date().toISOString(), updated_at: new Date().toISOString() })),
  });
  async function session(u, amr) {
    const now = Math.floor(Date.now() / 1000);
    const access_token = await sign({ sub: u.id, email: u.email, role: "authenticated", aud: "authenticated", aal: amr.some((a) => a.method === "totp") ? "aal2" : "aal1", amr, session_id: randomUUID() });
    const refresh_token = randomUUID();
    refresh.set(refresh_token, { userId: u.id, amr });
    return { access_token, token_type: "bearer", expires_in: 3600, expires_at: now + 3600, refresh_token, user: userJson(u) };
  }
  async function claims(req) {
    const h = req.headers.authorization ?? "";
    if (!h.startsWith("Bearer ")) return null;
    try { return (await jwtVerify(h.slice(7), key)).payload; } catch { return null; }
  }
  // Storage accepts a multipart form (storage-js sends Blobs that way): the file is the part with
  // an empty name; its own Content-Type is the object's type.
  function filePart(buf, header) {
    const boundary = Buffer.from(`--${/boundary=([^;]+)/.exec(header)[1].replace(/"/g, "")}`);
    let at = buf.indexOf(boundary);
    while (at !== -1) {
      const next = buf.indexOf(boundary, at + boundary.length);
      if (next === -1) break;
      const part = buf.subarray(at + boundary.length + 2, next - 2);
      const split = part.indexOf("\r\n\r\n");
      const head = part.subarray(0, split).toString();
      if (/name=""/.test(head) || /filename=/.test(head)) {
        return { bytes: Buffer.from(part.subarray(split + 4)), type: (/content-type:\s*([^\r\n;]+)/i.exec(head)?.[1] ?? "application/octet-stream").trim() };
      }
      at = next;
    }
    throw new Error("no file in the form");
  }
  const body = (req) => new Promise((ok) => { const c = []; req.on("data", (d) => c.push(d)); req.on("end", () => ok(Buffer.concat(c))); });
  const send = (res, status, obj, headers = {}) => { res.writeHead(status, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*", ...headers }); res.end(obj === undefined ? "" : JSON.stringify(obj)); };

  async function asUser(c, fn) {
    const client = await pool.connect();
    try {
      await client.query("begin");
      if (c?.role === "authenticated") {
        await client.query("set local role authenticated");
        await client.query("select set_config('request.jwt.claims', $1, true)", [JSON.stringify(c)]);
      }
      const out = await fn(client);
      await client.query("commit");
      return out;
    } catch (e) {
      await client.query("rollback").catch(() => {});
      throw e;
    } finally { client.release(); }
  }

  async function proxy(req, res, target) {
    const b = ["GET", "HEAD"].includes(req.method) ? undefined : await body(req);
    const headers = { ...req.headers };
    delete headers.host; delete headers["content-length"];
    const r = await fetch(target, { method: req.method, headers, body: b, redirect: "manual" });
    const out = Buffer.from(await r.arrayBuffer());
    const h = {}; r.headers.forEach((v, k) => { if (!["content-encoding", "transfer-encoding", "connection"].includes(k)) h[k] = v; });
    res.writeHead(r.status, h); res.end(out);
  }

  const server = createServer(async (req, res) => {
    try {
      const u = new URL(req.url, url);
      const p = u.pathname;
      if (req.method === "OPTIONS") return send(res, 204, undefined, { "Access-Control-Allow-Headers": "*", "Access-Control-Allow-Methods": "*" });
      if (p.startsWith("/rest/v1/")) return proxy(req, res, `http://127.0.0.1:${restPort}${p.slice(8)}${u.search}`);
      if (p.startsWith("/functions/v1/")) return proxy(req, res, `http://127.0.0.1:${edgePort}${p}${u.search}`);

      // ---- auth
      if (p === "/auth/v1/token") {
        const j = JSON.parse((await body(req)).toString() || "{}");
        if (u.searchParams.get("grant_type") === "password") {
          const user = await userRow("lower(email)", String(j.email ?? "").toLowerCase());
          if (!user || j.password !== PASSWORD) return send(res, 400, { error: "invalid_grant", error_description: "Invalid login credentials", code: "invalid_credentials" });
          return send(res, 200, await session(user, [{ method: "password", timestamp: Math.floor(Date.now() / 1000) }]));
        }
        if (u.searchParams.get("grant_type") === "refresh_token") {
          const r = refresh.get(j.refresh_token);
          if (!r) return send(res, 400, { error: "invalid_grant", code: "refresh_token_not_found" });
          refresh.delete(j.refresh_token);
          return send(res, 200, await session(await userRow("id", r.userId), r.amr));
        }
      }
      const c = await claims(req);
      if (p === "/auth/v1/user") {
        if (!c?.sub) return send(res, 401, { code: 401, msg: "invalid JWT" });
        return send(res, 200, userJson(await userRow("id", c.sub)));
      }
      if (p === "/auth/v1/logout") return send(res, 204);
      if (p === "/auth/v1/factors" && req.method === "POST") {
        if (!c?.sub) return send(res, 401, {});
        const f = { id: randomUUID(), status: "unverified" };
        factors.set(c.sub, [...(factors.get(c.sub) ?? []), f]);
        const qr = `data:image/svg+xml;utf8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="white"/><rect x="2" y="2" width="6" height="6"/></svg>')}`;
        return send(res, 200, { id: f.id, type: "totp", friendly_name: "Admin authenticator", totp: { qr_code: qr, secret: "LOCALTESTSECRET", uri: "otpauth://totp/local" } });
      }
      const m = p.match(/^\/auth\/v1\/factors\/([^/]+)\/(challenge|verify)$/);
      if (m) {
        if (!c?.sub) return send(res, 401, {});
        const f = (factors.get(c.sub) ?? []).find((x) => x.id === m[1]);
        if (!f) return send(res, 404, { code: "mfa_factor_not_found", msg: "factor not found" });
        if (m[2] === "challenge") return send(res, 200, { id: randomUUID(), type: "totp", expires_at: Math.floor(Date.now() / 1000) + 300 });
        const j = JSON.parse((await body(req)).toString() || "{}");
        if (j.code !== CODE) return send(res, 422, { code: "mfa_verification_failed", msg: "Invalid TOTP code entered" });
        f.status = "verified";
        const t = Math.floor(Date.now() / 1000);
        return send(res, 200, await session(await userRow("id", c.sub), [...(c.amr ?? []), { method: "totp", timestamp: t }]));
      }

      // ---- storage
      const so = p.match(/^\/storage\/v1\/object\/([^/]+)(?:\/(.+))?$/);
      if (so) {
        const [, bucket, name] = so;
        const path = name ? decodeURIComponent(name) : "";
        if (req.method === "POST" || req.method === "PUT") {
          let bytes = await body(req);
          let type = (req.headers["content-type"] ?? "application/octet-stream").split(";")[0];
          if (type === "multipart/form-data") ({ bytes, type } = filePart(bytes, req.headers["content-type"]));
          const b = (await pool.query("select file_size_limit, allowed_mime_types from storage.buckets where id = $1", [bucket])).rows[0];
          if (!b) return send(res, 404, { statusCode: "404", error: "Bucket not found", message: "Bucket not found" });
          if (b.file_size_limit && bytes.length > Number(b.file_size_limit)) return send(res, 413, { statusCode: "413", error: "Payload too large", message: "The object exceeded the maximum allowed size" });
          if (b.allowed_mime_types && !b.allowed_mime_types.includes(type)) return send(res, 415, { statusCode: "415", error: "invalid_mime_type", message: `mime type ${type} is not supported` });
          try {
            await asUser(c?.role === "service_role" ? null : c ?? { role: "anon" }, async (db) => {
              if (!c || c.role === "anon") throw Object.assign(new Error("new row violates row-level security policy"), { code: "42501" });
              await db.query("insert into storage.objects (bucket_id, name, owner, metadata) values ($1, $2, $3, $4)",
                [bucket, path, c.sub ?? null, JSON.stringify({ mimetype: type, size: bytes.length })]);
            });
          } catch (e) {
            return send(res, e.code === "23505" ? 409 : 403, { statusCode: e.code === "23505" ? "409" : "403", error: "Unauthorized", message: e.message });
          }
          mkdirSync(dirname(join(files_, bucket, path)), { recursive: true });
          writeFileSync(join(files_, bucket, path), bytes);
          return send(res, 200, { Key: `${bucket}/${path}`, Id: randomUUID() });
        }
        if (req.method === "GET") {
          if (c?.role !== "service_role") return send(res, 400, { statusCode: "404", error: "not_found", message: "Object not found" });
          const f = join(files_, bucket, path);
          if (!existsSync(f)) return send(res, 400, { statusCode: "404", error: "not_found", message: "Object not found" });
          res.writeHead(200, { "Content-Type": "application/octet-stream" });
          return res.end(readFileSync(f));
        }
        if (req.method === "DELETE") {
          if (c?.role !== "service_role") return send(res, 403, { message: "forbidden" });
          const j = JSON.parse((await body(req)).toString() || "{}");
          for (const n of j.prefixes ?? []) {
            await pool.query("delete from storage.objects where bucket_id = $1 and name = $2", [bucket, n]);
            rmSync(join(files_, bucket, n), { force: true });
          }
          return send(res, 200, (j.prefixes ?? []).map((n) => ({ name: n })));
        }
      }
      send(res, 404, { message: `no route ${req.method} ${p}` });
    } catch (e) {
      send(res, 500, { message: String(e?.message ?? e) });
    }
  });
  await new Promise((ok) => server.listen(gwPort, "127.0.0.1", ok));

  // ---- the admin Edge Function (Deno)
  const edge = spawn("deno", ["run", "--allow-net", "--allow-env", "--allow-read", "--allow-sys", join(root, "supabase/functions/admin/index.ts")], {
    env: { ...process.env, LOCAL_EDGE_PORT: String(edgePort), SUPABASE_URL: url, SUPABASE_ANON_KEY: anonKey, SUPABASE_SERVICE_ROLE_KEY: serviceKey, SUPABASE_DB_URL: dbUrl },
  });
  procs.push(edge); log(edge, "edge");
  await waitFor(`http://127.0.0.1:${edgePort}/functions/v1/admin/x`, 60000);

  // However the test runner ends us (Playwright kills its web server, Ctrl-C, a crash), leave
  // nothing running: stop the cluster and the child processes, synchronously, on exit.
  let stopped = false;
  const hardStop = () => {
    if (stopped) return;
    stopped = true;
    for (const p of procs) { try { p.kill("SIGKILL"); } catch { /* gone */ } }
    try { execFileSync(`${PG_BIN}/pg_ctl`, ["-D", join(tmp, "db"), "stop", "-m", "immediate"], { stdio: "ignore" }); } catch { /* down */ }
    try { rmSync(tmp, { recursive: true, force: true }); } catch { /* ignore */ }
  };
  process.once("exit", hardStop);
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) process.once(sig, () => { hardStop(); process.exit(0); });

  return {
    url, anonKey, dbUrl, pool, tmp, pids: () => procs.map((p) => p.pid), storageDir: files_,
    /** Reads a stored file (what a parent would download). */
    file: (bucket, path) => readFileSync(join(files_, bucket, path)),
    async stop() {
      server.close();
      for (const p of procs) p.kill("SIGTERM");
      await pool.end().catch(() => {});
      try { execFileSync(`${PG_BIN}/pg_ctl`, ["-D", join(tmp, "db"), "stop", "-m", "fast"], { stdio: "ignore" }); } catch { /* already down */ }
      rmSync(tmp, { recursive: true, force: true });
    },
  };
}

// `node test/stack/stack.mjs` keeps a stack running and prints its settings (manual testing).
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const s = await startStack({ quiet: false });
  console.log(`NEXT_PUBLIC_SUPABASE_URL=${s.url}\nNEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=${s.anonKey}`);
  process.on("SIGINT", async () => { await s.stop(); process.exit(0); });
}
