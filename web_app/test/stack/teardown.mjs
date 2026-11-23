// Playwright global teardown: stop whatever the e2e web server started, even if the runner killed
// it without letting it clean up (Postgres runs detached through pg_ctl and would outlive it).
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";

export default async function teardown() {
  const f = join(process.cwd(), "test/e2e/.stack.pids");
  if (!existsSync(f)) return;
  const { tmp, pids } = JSON.parse(readFileSync(f, "utf8"));
  for (const pid of pids ?? []) { try { process.kill(pid, "SIGKILL"); } catch { /* gone */ } }
  try { execFileSync(`${process.env.PG_BIN ?? "/opt/homebrew/opt/postgresql@17/bin"}/pg_ctl`, ["-D", join(tmp, "db"), "stop", "-m", "immediate"], { stdio: "ignore" }); } catch { /* down */ }
  rmSync(tmp, { recursive: true, force: true });
  rmSync(f, { force: true });
  rmSync(join(process.cwd(), "test/e2e/.stack.json"), { force: true }); // holds the throwaway local key
}
