import { defineWorkspace } from "vitest/config";
import { alias } from "./vitest.config";

export default defineWorkspace([
  { resolve: { alias }, test: { name: "unit", include: ["test/unit/**/*.test.ts"], environment: "node" } },
  {
    resolve: { alias },
    test: {
      name: "integration", include: ["test/integration/**/*.test.ts"], environment: "node",
      globalSetup: ["test/integration/setup.ts"], testTimeout: 30000, hookTimeout: 240000,
      poolOptions: { forks: { singleFork: true } },
    },
  },
]);
