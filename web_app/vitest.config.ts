import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

export const alias = {
  "@": fileURLToPath(new URL("./src", import.meta.url)),
  "server-only": fileURLToPath(new URL("./test/server-only-stub.ts", import.meta.url)),
};
export default defineConfig({ resolve: { alias } });
