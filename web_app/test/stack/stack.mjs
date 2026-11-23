// LOCAL TEST ONLY. A stand-in for a Supabase project for the web app's integration and
// end-to-end tests (no Docker or Supabase CLI on the build machine):
//   Postgres 17   every migration + seed.sql (the real schema, RLS and functions)
//   PostgREST 16  the real Data API (schema public), JWTs checked with a local secret
//   Deno          the real Edge Functions: onboarding, children, play, progress, account
//   gateway       /rest/v1 → PostgREST; /functions/v1/<fn> → Deno;
//                 /auth/v1  stub GoTrue: password sign-in, email codes (sign-up, sign-in, recovery),
//                           refresh, user, update password, sign-out. Codes go to an in-memory
//                           "mailbox" the tests read (GET /__test/mailbox?email=…);
//                 /storage/v1 stub: signed URLs, public URLs, byte ranges. Files come from the
//                           development media library (kids_app/assets/dev_media/<bucket>/<path>)
//                           and from objects uploaded during the run (exports).
// Never point this at real data. Seeded parents sign in with the fixed test password.
import { spawn, execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, readdirSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { randomInt, randomUUID } from "node:crypto";
import { SignJWT, jwtVerify } from "jose";
import pg from "pg";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..", "..");
const PG_BIN = process.env.PG_BIN ?? "/opt/homebrew/opt/postgresql@17/bin";
export const PASSWORD = "Parent-pass-123";
const SECRET = "local-test-jwt-secret-at-least-32-characters-long";
const key = new TextEncoder().encode(SECRET);
const FUNCTIONS = ["onboarding", "children", "play", "progress", "account"];
const MEDIA = join(root, "kids_app/assets/dev_media");
const MIME = { ".webp": "image/webp", ".png": "image/png", ".jpg": "image/jpeg", ".mp4": "video/mp4", ".m4a": "audio/mp4", ".mp3": "audio/mpeg", ".vtt": "text/vtt", ".json": "application/json", ".pdf": "application/pdf" };
const usedPorts = new Set();
const free = () => { let p; do p = 20000 + randomInt(20000); while (usedPorts.has(p)); usedPorts.add(p); return p; };

const sign = (claims, ttl = 3600) =>
  new SignJWT(claims).setProtectedHeader({ alg: "HS256", typ: "JWT" }).setIssuedAt().setExpirationTime(Math.floor(Date.now() / 1000) + ttl).sign(key);

function waitFor(url, ms = 60000) {
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
  const tmp = mkdtempSync(join(tmpdir(), "kl-web-stack-"));
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
    join(root, "supabase/seed.sql"), join(here, "seed_web.sql")];
  for (const f of files) psql(["-d", "kl", "-f", f]);
  const dbUrl = `postgres://postgres@localhost:${pgPort}/kl`;
  const pool = new pg.Pool({ connectionString: dbUrl, max: 4 });

  // ---- PostgREST
  const restPort = free();
  writeFileSync(join(tmp, "postgrest.conf"), [
    `db-uri = "postgres://authenticator@localhost:${pgPort}/kl"`,
    `db-schemas = "public"`, `db-anon-role = "anon"`, `jwt-secret = "${SECRET}"`,
    `server-port = ${restPort}`, `server-host = "127.0.0.1"`, `db-pool = 6`, `log-level = "crit"`,
  ].join("\n"));
  const rest = spawn("postgrest", [join(tmp, "postgrest.conf")]); procs.push(rest); log(rest, "rest");
  await waitFor(`http://127.0.0.1:${restPort}/`);

  const anonKey = await sign({ role: "anon", iss: "local" }, 86400 * 365);
  const serviceKey = await sign({ role: "service_role", iss: "local" }, 86400 * 365);

  // ---- gateway state
  const gwPort = free();
  const url = `http://localhost:${gwPort}`;
  const fnPorts = Object.fromEntries(FUNCTIONS.map((f) => [f, free()]));
  const passwords = new Map(); // userId → password (seeded users default to PASSWORD)
  const mailbox = new Map(); // email → [{type, code, at}]
  const codes = new Map(); // `${email}|${type}` → code
  const refresh = new Map();
  const uploads = join(tmp, "storage");

  const userRow = async (where, v) => (await pool.query(`select id, email, created_at from auth.users where ${where} = $1`, [v])).rows[0];
  const userJson = (u) => ({
    id: u.id, aud: "authenticated", role: "authenticated", email: u.email, email_confirmed_at: new Date().toISOString(),
    app_metadata: { provider: "email", providers: ["email"] }, user_metadata: {}, identities: [],
    created_at: new Date(u.created_at ?? Date.now()).toISOString(), updated_at: new Date().toISOString(),
  });
  async function session(u, amr) {
    const now = Math.floor(Date.now() / 1000);
    const access_token = await sign({ sub: u.id, email: u.email, role: "authenticated", aud: "authenticated", aal: "aal1", amr, session_id: randomUUID() });
    const refresh_token = randomUUID();
    refresh.set(refresh_token, { userId: u.id, amr });
    return { access_token, token_type: "bearer", expires_in: 3600, expires_at: now + 3600, refresh_token, user: userJson(u) };
  }
  const now = () => Math.floor(Date.now() / 1000);
  async function claims(req) {
    const h = req.headers.authorization ?? "";
    if (!h.startsWith("Bearer ")) return null;
    try { return (await jwtVerify(h.slice(7), key)).payload; } catch { return null; }
  }
  const body = (req) => new Promise((ok) => { const c = []; req.on("data", (d) => c.push(d)); req.on("end", () => ok(Buffer.concat(c))); });
  const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "*", "Access-Control-Allow-Methods": "*", "Access-Control-Expose-Headers": "*" };
  const send = (res, status, obj, headers = {}) => { res.writeHead(status, { "Content-Type": "application/json", ...cors, ...headers }); res.end(obj === undefined ? "" : JSON.stringify(obj)); };
  function mail(email, type) {
    const code = String(randomInt(1000000)).padStart(6, "0");
    codes.set(`${email}|${type}`, code);
    mailbox.set(email, [...(mailbox.get(email) ?? []), { type, code, at: new Date().toISOString() }]);
  }
  async function createUser(email) {
    const id = randomUUID();
    await pool.query("insert into auth.users (id, email, role, aud, email_confirmed_at) values ($1, $2, 'authenticated', 'authenticated', now())", [id, email]);
    return userRow("id", id);
  }

  async function proxy(req, res, target) {
    const b = ["GET", "HEAD"].includes(req.method) ? undefined : await body(req);
    const headers = { ...req.headers };
    delete headers.host; delete headers["content-length"];
    const r = await fetch(target, { method: req.method, headers, body: b, redirect: "manual" });
    const out = Buffer.from(await r.arrayBuffer());
    const h = { ...cors }; r.headers.forEach((v, k) => { if (!["content-encoding", "transfer-encoding", "connection"].includes(k)) h[k] = v; });
    res.writeHead(r.status, h); res.end(out);
  }
  function serveFile(req, res, file) {
    const data = readFileSync(file);
    const type = MIME[extname(file)] ?? "application/octet-stream";
    const range = /bytes=(\d*)-(\d*)/.exec(req.headers.range ?? "");
    if (range) {
      const start = range[1] ? Number(range[1]) : 0;
      const end = range[2] ? Math.min(Number(range[2]), data.length - 1) : data.length - 1;
      res.writeHead(206, { ...cors, "Content-Type": type, "Accept-Ranges": "bytes", "Content-Range": `bytes ${start}-${end}/${data.length}`, "Content-Length": end - start + 1 });
      return res.end(data.subarray(start, end + 1));
    }
    res.writeHead(200, { ...cors, "Content-Type": type, "Accept-Ranges": "bytes", "Content-Length": data.length, "Cache-Control": "private, max-age=300" });
    res.end(data);
  }
  const findObject = (bucket, path) => [join(uploads, bucket, path), join(MEDIA, bucket, path)].find((f) => existsSync(f) && statSync(f).isFile());

  const server = createServer(async (req, res) => {
    try {
      const u = new URL(req.url, url);
      const p = u.pathname;
      if (req.method === "OPTIONS") return send(res, 204);
      if (p.startsWith("/rest/v1/")) return proxy(req, res, `http://127.0.0.1:${restPort}${p.slice(8)}${u.search}`);
      const fm = p.match(/^\/functions\/v1\/([^/]+)/);
      if (fm) {
        if (!fnPorts[fm[1]]) return send(res, 404, { message: "function not found" });
        return proxy(req, res, `http://127.0.0.1:${fnPorts[fm[1]]}${p}${u.search}`);
      }
      if (p === "/__test/mailbox") return send(res, 200, mailbox.get(String(u.searchParams.get("email")).toLowerCase()) ?? []);

      // ---- auth
      if (p === "/auth/v1/token") {
        const j = JSON.parse((await body(req)).toString() || "{}");
        const grant = u.searchParams.get("grant_type");
        if (grant === "password") {
          const user = await userRow("lower(email)", String(j.email ?? "").toLowerCase());
          const expected = user && (passwords.get(user.id) ?? PASSWORD);
          if (!user || j.password !== expected) return send(res, 400, { error: "invalid_grant", error_description: "Invalid login credentials", code: "invalid_credentials", msg: "Invalid login credentials" });
          return send(res, 200, await session(user, [{ method: "password", timestamp: now() }]));
        }
        if (grant === "refresh_token") {
          const r = refresh.get(j.refresh_token);
          if (!r) return send(res, 400, { error: "invalid_grant", code: "refresh_token_not_found", msg: "Invalid Refresh Token" });
          refresh.delete(j.refresh_token);
          return send(res, 200, await session(await userRow("id", r.userId), r.amr));
        }
        if (grant === "pkce") return send(res, 400, { code: "flow_state_not_found", msg: "not supported by the test stack" });
      }
      if (p === "/auth/v1/otp" && req.method === "POST") {
        const j = JSON.parse((await body(req)).toString() || "{}");
        const email = String(j.email ?? "").toLowerCase();
        if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return send(res, 400, { code: "validation_failed", msg: "Unable to validate email address: invalid format" });
        const exists = await userRow("lower(email)", email);
        if (!exists && j.create_user === false) return send(res, 400, { code: "otp_disabled", msg: "Signups not allowed for otp" });
        mail(email, "email");
        return send(res, 200, {});
      }
      if (p === "/auth/v1/recover" && req.method === "POST") {
        const j = JSON.parse((await body(req)).toString() || "{}");
        const email = String(j.email ?? "").toLowerCase();
        if (await userRow("lower(email)", email)) mail(email, "recovery"); // no reply difference: no account probing
        return send(res, 200, {});
      }
      if (p === "/auth/v1/verify" && req.method === "POST") {
        const j = JSON.parse((await body(req)).toString() || "{}");
        const email = String(j.email ?? "").toLowerCase();
        const type = j.type === "recovery" ? "recovery" : "email";
        const code = codes.get(`${email}|${type}`);
        if (!code || code !== String(j.token ?? "")) return send(res, 403, { code: "otp_expired", msg: "Token has expired or is invalid" });
        codes.delete(`${email}|${type}`);
        const user = (await userRow("lower(email)", email)) ?? (await createUser(email));
        return send(res, 200, await session(user, [{ method: type === "recovery" ? "otp" : "otp", timestamp: now() }]));
      }
      const c = await claims(req);
      if (p === "/auth/v1/user") {
        if (!c?.sub) return send(res, 401, { code: "bad_jwt", msg: "invalid JWT" });
        const user = await userRow("id", c.sub);
        if (!user) return send(res, 404, { code: "user_not_found", msg: "User from sub claim in JWT does not exist" });
        if (req.method === "PUT") {
          const j = JSON.parse((await body(req)).toString() || "{}");
          if (j.password !== undefined) {
            if (String(j.password).length < 10) return send(res, 422, { code: "weak_password", msg: "Password should be at least 10 characters." });
            passwords.set(user.id, String(j.password));
          }
        }
        return send(res, 200, userJson(user));
      }
      if (p === "/auth/v1/logout") {
        for (const [t, r] of refresh) if (r.userId === c?.sub) refresh.delete(t); // sign out everywhere (scope global)
        return send(res, 204);
      }

      // ---- storage
      const signM = p.match(/^\/storage\/v1\/object\/sign\/([^/]+)(?:\/(.+))?$/);
      if (signM && req.method === "POST") {
        if (c?.role !== "service_role") return send(res, 403, { message: "forbidden" });
        const [, bucket, one] = signM;
        const j = JSON.parse((await body(req)).toString() || "{}");
        const exp = Number(j.expiresIn ?? 3600);
        const mk = async (path) => ({ path, error: null, signedURL: `/object/sign/${bucket}/${path.split("/").map(encodeURIComponent).join("/")}?token=${await sign({ url: `${bucket}/${path}` }, exp)}` });
        if (one) return send(res, 200, { signedURL: (await mk(decodeURIComponent(one))).signedURL });
        return send(res, 200, await Promise.all((j.paths ?? []).map(mk)));
      }
      if (signM && (req.method === "GET" || req.method === "HEAD")) {
        const [, bucket, raw] = signM;
        const path = decodeURIComponent(raw ?? "");
        try {
          const t = (await jwtVerify(String(u.searchParams.get("token")), key)).payload;
          if (t.url !== `${bucket}/${path}`) throw new Error("wrong object");
        } catch { return send(res, 400, { statusCode: "403", error: "InvalidJWT", message: "invalid signature" }); }
        const f = findObject(bucket, path);
        return f ? serveFile(req, res, f) : send(res, 404, { statusCode: "404", error: "not_found", message: "Object not found" });
      }
      const pub = p.match(/^\/storage\/v1\/object\/public\/([^/]+)\/(.+)$/);
      if (pub) {
        const [, bucket, raw] = pub;
        const b = (await pool.query("select public from storage.buckets where id = $1", [bucket])).rows[0];
        if (!b?.public) return send(res, 400, { statusCode: "404", error: "Bucket not found", message: "Bucket not found" });
        const f = findObject(bucket, decodeURIComponent(raw));
        return f ? serveFile(req, res, f) : send(res, 404, { statusCode: "404", error: "not_found", message: "Object not found" });
      }
      const so = p.match(/^\/storage\/v1\/object\/([^/]+)\/(.+)$/);
      if (so && (req.method === "POST" || req.method === "PUT")) {
        if (c?.role !== "service_role") return send(res, 403, { message: "only the service role writes in this stub" });
        const [, bucket, raw] = so;
        let bytes = await body(req);
        const ct = req.headers["content-type"] ?? "";
        if (ct.startsWith("multipart/form-data")) {
          const boundary = Buffer.from(`--${/boundary=([^;]+)/.exec(ct)[1].replace(/"/g, "")}`);
          const parts = []; let at = bytes.indexOf(boundary);
          while (at !== -1) { const next = bytes.indexOf(boundary, at + boundary.length); if (next === -1) break; parts.push(bytes.subarray(at + boundary.length + 2, next - 2)); at = next; }
          const file = parts.find((x) => /name=""|filename=/.test(x.subarray(0, x.indexOf("\r\n\r\n")).toString()));
          bytes = Buffer.from(file.subarray(file.indexOf("\r\n\r\n") + 4));
        }
        const path = decodeURIComponent(raw);
        mkdirSync(dirname(join(uploads, bucket, path)), { recursive: true });
        writeFileSync(join(uploads, bucket, path), bytes);
        await pool.query("insert into storage.objects (bucket_id, name, metadata) values ($1, $2, $3) on conflict do nothing", [bucket, path, JSON.stringify({ size: bytes.length })]).catch(() => {});
        return send(res, 200, { Key: `${bucket}/${path}` });
      }
      send(res, 404, { message: `no route ${req.method} ${p}` });
    } catch (e) {
      send(res, 500, { message: String(e?.message ?? e) });
    }
  });
  await new Promise((ok) => server.listen(gwPort, "127.0.0.1", ok));

  // ---- the Edge Functions (Deno)
  for (const fn of FUNCTIONS) {
    const p = spawn("deno", ["run", "--allow-net", "--allow-env", "--allow-read", "--allow-sys", join(root, `supabase/functions/${fn}/index.ts`)], {
      env: { ...process.env, LOCAL_EDGE_PORT: String(fnPorts[fn]), SUPABASE_URL: url, SUPABASE_ANON_KEY: anonKey, SUPABASE_PUBLISHABLE_KEY: anonKey,
        SUPABASE_SERVICE_ROLE_KEY: serviceKey, SUPABASE_DB_URL: dbUrl, EVIDENCE_SALT: "local-test-salt" },
    });
    procs.push(p); log(p, fn);
  }
  await Promise.all(FUNCTIONS.map((fn) => waitFor(`http://127.0.0.1:${fnPorts[fn]}/functions/v1/${fn}/x`)));

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
    url, anonKey, dbUrl, pool, tmp, pids: () => procs.map((p) => p.pid),
    /** The last code mailed to [email] (sign-up / sign-in or recovery). */
    code: (email, type = "email") => [...(mailbox.get(email.toLowerCase()) ?? [])].reverse().find((m) => m.type === type)?.code,
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
