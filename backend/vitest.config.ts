import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["test/**/*.test.ts"],
    // node:sqlite (used by test/usage.test.ts) prints an ExperimentalWarning on Node 22.
    execArgv: ["--disable-warning=ExperimentalWarning"],
  },
});
