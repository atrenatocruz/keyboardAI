import { readFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { describe, expect, it } from "vitest";
import { D1UsageStore, MemoryUsageStore, type UsageStore } from "../src/usage";

function fakeD1(): D1Database {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(join(import.meta.dirname, "../migrations/0001_usage.sql"), "utf8"));
  const prepare = (sql: string) => {
    let params: unknown[] = [];
    const stmt = {
      bind: (...p: unknown[]) => ((params = p), stmt),
      first: async () => (db.prepare(sql).get(...(params as never[])) as unknown) ?? null,
      run: async () => (db.prepare(sql).run(...(params as never[])), { success: true }),
    };
    return stmt;
  };
  return { prepare } as unknown as D1Database;
}

const stores: [string, () => UsageStore][] = [
  ["D1UsageStore", () => new D1UsageStore(fakeD1())],
  ["MemoryUsageStore", () => new MemoryUsageStore()],
];

describe.each(stores)("%s", (_name, make) => {
  it("starts at zero", async () => {
    const s = make();
    expect(await s.getCount("a", "2026-10-09")).toBe(0);
    expect(await s.getGlobalCount("2026-10-09")).toBe(0);
  });
  it("increments per install and day, and sums globally", async () => {
    const s = make();
    await s.increment("a", "2026-10-09");
    await s.increment("a", "2026-10-09");
    await s.increment("b", "2026-10-09");
    await s.increment("a", "2026-10-10");
    expect(await s.getCount("a", "2026-10-09")).toBe(2);
    expect(await s.getCount("b", "2026-10-09")).toBe(1);
    expect(await s.getCount("a", "2026-10-10")).toBe(1);
    expect(await s.getGlobalCount("2026-10-09")).toBe(3);
  });
});
