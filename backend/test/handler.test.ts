import { afterEach, describe, expect, it, vi } from "vitest";
import { createHandler, type HandlerDeps } from "../src/handler";
import { UpstreamError, type LLM } from "../src/llm";
import { MemoryUsageStore } from "../src/usage";

const ID = "3f2b8c1e-4a5d-4e6f-8a9b-0c1d2e3f4a5b";
const SECRET = "mensagem muito privada do utilizador";

function setup(overrides: Partial<HandlerDeps> = {}) {
  const llm: LLM = { improve: vi.fn(async (t: string) => `Melhorado: ${t}`) };
  const store = new MemoryUsageStore();
  const deps: HandlerDeps = {
    llm,
    store,
    now: () => new Date("2026-10-09T12:00:00Z"),
    perInstallLimit: 3,
    globalLimit: 10,
    ...overrides,
  };
  return { handler: createHandler(deps), llm: deps.llm, store: deps.store };
}

function post(body: unknown, id: string | null = ID, path = "/v1/improve") {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (id) headers["X-Install-ID"] = id;
  return new Request(`https://w.example${path}`, {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

afterEach(() => vi.restoreAllMocks());

describe("POST /v1/improve", () => {
  it("returns improved text and remaining count", async () => {
    const { handler, llm, store } = setup();
    const res = await handler(post({ text: "boas", mood: "simpatico" }));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ text: "Melhorado: boas", remaining: 2 });
    expect(llm.improve).toHaveBeenCalledWith("boas", "simpatico");
    expect(await store.getCount(ID, "2026-10-09")).toBe(1);
  });

  it("returns 400 for invalid JSON, bad mood or missing id", async () => {
    const { handler, llm } = setup();
    expect((await handler(post("{not json"))).status).toBe(400);
    expect((await handler(post({ text: "a", mood: "x" }))).status).toBe(400);
    expect((await handler(post({ text: "a", mood: "natural" }, null))).status).toBe(400);
    expect(llm.improve).not.toHaveBeenCalled();
  });

  it("returns 429 when the per-install limit is reached", async () => {
    const { handler } = setup();
    for (let i = 0; i < 3; i++) expect((await handler(post({ text: "a", mood: "natural" }))).status).toBe(200);
    const res = await handler(post({ text: "a", mood: "natural" }));
    expect(res.status).toBe(429);
    expect(await res.json()).toEqual({ error: "daily_limit" });
  });

  it("returns 429 when the global limit is reached", async () => {
    const store = new MemoryUsageStore();
    for (let i = 0; i < 10; i++) await store.increment(`other-${i}`, "2026-10-09");
    const { handler } = setup({ store });
    expect((await handler(post({ text: "a", mood: "natural" }))).status).toBe(429);
  });

  it("returns 502 on upstream failure and does not count it", async () => {
    const llm: LLM = { improve: vi.fn(async () => { throw new UpstreamError("refusal"); }) };
    const { handler, store } = setup({ llm });
    const res = await handler(post({ text: "a", mood: "natural" }));
    expect(res.status).toBe(502);
    expect(await res.json()).toEqual({ error: "upstream" });
    expect(await store.getCount(ID, "2026-10-09")).toBe(0);
  });

  it("returns 404 for other paths and 405 for other methods", async () => {
    const { handler } = setup();
    expect((await handler(post({}, ID, "/other"))).status).toBe(404);
    expect((await handler(new Request("https://w.example/v1/improve"))).status).toBe(405);
  });

  it("never logs the user's text", async () => {
    const spies = (["log", "info", "warn", "error", "debug"] as const).map((m) =>
      vi.spyOn(console, m).mockImplementation(() => {}),
    );
    const failing: LLM = { improve: vi.fn(async () => { throw new Error(SECRET); }) };
    for (const deps of [{}, { llm: failing }]) {
      const { handler } = setup(deps);
      await handler(post({ text: SECRET, mood: "natural" }));
    }
    for (const spy of spies)
      for (const call of spy.mock.calls) expect(JSON.stringify(call)).not.toContain(SECRET);
  });
});
