// Starts the local stack, builds the app against it and serves it on :3110 (Playwright webServer).
import { spawn, execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { startStack } from "./stack.mjs";

const app = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const s = await startStack();
writeFileSync(join(app, "test/e2e/.stack.json"), JSON.stringify({ dbUrl: s.dbUrl, storageDir: s.storageDir, tmp: s.tmp, pids: s.pids() }));
const env = { ...process.env, NEXT_PUBLIC_SUPABASE_URL: s.url, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: s.anonKey, NEXT_TELEMETRY_DISABLED: "1" };
execFileSync("npx", ["next", "build"], { cwd: app, env, stdio: "inherit" });
const next = spawn(join(app, "node_modules/.bin/next"), ["start", "-p", "3110"], { cwd: app, env, stdio: "inherit" });
writeFileSync(join(app, "test/e2e/.stack.pids"), JSON.stringify({ tmp: s.tmp, pids: [...s.pids(), next.pid, process.pid] }));
process.once("exit", () => { try { next.kill("SIGKILL"); } catch { /* gone */ } });
const stop = async () => { next.kill("SIGTERM"); await s.stop(); process.exit(0); };
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
