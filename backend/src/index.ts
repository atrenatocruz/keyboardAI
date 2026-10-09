import Anthropic from "@anthropic-ai/sdk";
import { parseLimit } from "./config";
import { createHandler } from "./handler";
import { AnthropicLLM } from "./llm";
import { D1UsageStore } from "./usage";

export interface Env {
  DB: D1Database;
  ANTHROPIC_API_KEY: string;
  PER_INSTALL_DAILY_LIMIT?: string;
  GLOBAL_DAILY_LIMIT?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const handler = createHandler({
      llm: new AnthropicLLM(new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, timeout: 6000, maxRetries: 0 })),
      store: new D1UsageStore(env.DB),
      now: () => new Date(),
      perInstallLimit: parseLimit(env.PER_INSTALL_DAILY_LIMIT, 200),
      globalLimit: parseLimit(env.GLOBAL_DAILY_LIMIT, 1000),
    });
    return handler(request);
  },
} satisfies ExportedHandler<Env>;
