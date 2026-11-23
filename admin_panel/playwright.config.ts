import { defineConfig, devices } from "@playwright/test";

// End-to-end: the real app (next build + next start) against the local stack (test/stack).
export default defineConfig({
  testDir: "test/e2e",
  fullyParallel: false,
  workers: 1,
  timeout: 60000,
  reporter: [["list"]],
  use: { baseURL: "http://localhost:3110", trace: "retain-on-failure", screenshot: "only-on-failure" },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"], channel: "chrome", viewport: { width: 1440, height: 900 } } },
    { name: "tablet", use: { ...devices["Desktop Chrome"], channel: "chrome", viewport: { width: 820, height: 1180 } }, grep: /@responsive/ },
  ],
  globalTeardown: "./test/stack/teardown.mjs",
  webServer: { command: "node test/stack/serve-e2e.mjs", url: "http://localhost:3110/api/health", timeout: 600000, reuseExistingServer: false },
});
