import { defineConfig, devices } from "@playwright/test";

// End-to-end: the real app (next build + next start) against the local stack (test/stack).
// Viewports: desktop 1440, laptop 1280, tablet 820 (portrait), phone 390 (touch).
export default defineConfig({
  testDir: "test/e2e",
  fullyParallel: false,
  workers: 1,
  timeout: 90000,
  expect: { timeout: 10000 },
  reporter: [["list"]],
  use: { baseURL: "http://localhost:3210", trace: "retain-on-failure", screenshot: "only-on-failure" },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"], channel: "chrome", viewport: { width: 1440, height: 900 } }, grepInvert: /@phone-only/ },
    { name: "laptop", use: { ...devices["Desktop Chrome"], channel: "chrome", viewport: { width: 1280, height: 800 } }, grep: /@responsive/ },
    { name: "tablet", use: { ...devices["Desktop Chrome"], channel: "chrome", viewport: { width: 820, height: 1180 }, hasTouch: true }, grep: /@responsive/ },
    { name: "phone", use: { ...devices["Pixel 7"], channel: "chrome" }, grep: /@responsive|@touch|@phone-only/ },
  ],
  globalTeardown: "./test/stack/teardown.mjs",
  webServer: { command: "node test/stack/serve-e2e.mjs", url: "http://localhost:3210/api/health", timeout: 600000, reuseExistingServer: !!process.env.REUSE },
});
