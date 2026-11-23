// Starts the local stack once for every integration test file (see test/stack/stack.mjs).
import type { TestProject } from "vitest/node";
import { startStack } from "../stack/stack.mjs";

let stop: (() => Promise<void>) | undefined;

export default async function setup(project: TestProject) {
  const s = await startStack();
  stop = s.stop;
  project.provide("stack", { url: s.url, anonKey: s.anonKey, dbUrl: s.dbUrl, storageDir: s.storageDir });
  return async () => { await stop?.(); };
}

declare module "vitest" {
  export interface ProvidedContext {
    stack: { url: string; anonKey: string; dbUrl: string; storageDir: string };
  }
}
