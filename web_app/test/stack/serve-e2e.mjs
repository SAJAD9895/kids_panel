// Starts the local stack, builds the app against it and serves it on :3210 (Playwright webServer).
import { spawn, execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { startStack } from "./stack.mjs";

const app = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const s = await startStack();
writeFileSync(join(app, "test/e2e/.stack.json"), JSON.stringify({ dbUrl: s.dbUrl, url: s.url, anonKey: s.anonKey, tmp: s.tmp, pids: s.pids() }));
const env = { ...process.env, NEXT_PUBLIC_SUPABASE_URL: s.url, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: s.anonKey, NEXT_TELEMETRY_DISABLED: "1" };
if (!process.env.SKIP_BUILD) execFileSync("npx", ["next", "build"], { cwd: app, env, stdio: "inherit" });
const next = spawn(join(app, "node_modules/.bin/next"), ["start", "-p", "3210"], { cwd: app, env, stdio: "inherit" });
// the tests read mailed codes from the stack's mailbox through this little side port
createServer((req, res) => { const e = new URL(req.url, "http://x").searchParams.get("email") ?? ""; res.end(JSON.stringify({ code: s.code(e), recovery: s.code(e, "recovery") })); }).listen(3211);
writeFileSync(join(app, "test/e2e/.stack.pids"), JSON.stringify({ tmp: s.tmp, pids: [...s.pids(), next.pid, process.pid] }));
process.once("exit", () => { try { next.kill("SIGKILL"); } catch { /* gone */ } });
const stop = async () => { next.kill("SIGTERM"); await s.stop(); process.exit(0); };
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
