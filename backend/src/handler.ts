import { UpstreamError, type LLM } from "./llm";
import type { UsageStore } from "./usage";
import { validateRequest } from "./validate";

export interface HandlerDeps {
  llm: LLM;
  store: UsageStore;
  now: () => Date;
  perInstallLimit: number;
  globalLimit: number;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

export function createHandler(deps: HandlerDeps): (request: Request) => Promise<Response> {
  return async (request) => {
    const url = new URL(request.url);
    if (url.pathname !== "/v1/improve") return json(404, { error: "not_found" });
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return json(400, { error: "invalid_request" });
    }
    const v = validateRequest(request.headers.get("X-Install-ID"), body);
    if (!v.ok) return json(400, { error: "invalid_request" });
    const { installId, text, mood } = v.value;

    try {
      const day = deps.now().toISOString().slice(0, 10);
      const [count, global] = await Promise.all([
        deps.store.getCount(installId, day),
        deps.store.getGlobalCount(day),
      ]);
      if (count >= deps.perInstallLimit || global >= deps.globalLimit) {
        return json(429, { error: "daily_limit" });
      }

      let improved: string;
      try {
        improved = await deps.llm.improve(text, mood);
      } catch (err) {
        // Only the reason code is logged — never the user's text or the raw error message.
        console.error("upstream_error", err instanceof UpstreamError ? err.reason : "unknown");
        return json(502, { error: "upstream" });
      }

      await deps.store.increment(installId, day);
      return json(200, { text: improved, remaining: Math.max(0, deps.perInstallLimit - count - 1) });
    } catch (err) {
      console.error("internal_error", err instanceof Error ? err.name : "unknown");
      return json(500, { error: "internal" });
    }
  };
}
