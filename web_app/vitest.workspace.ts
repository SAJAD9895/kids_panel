import { defineWorkspace } from "vitest/config";
import { alias } from "./vitest.config";

// Unit tests only; the integration tests are the Playwright journeys against the local stack.
export default defineWorkspace([
  { resolve: { alias }, test: { name: "unit", include: ["test/unit/**/*.test.ts"], environment: "node" } },
]);
