import Anthropic from "@anthropic-ai/sdk";
import { buildSystemPrompt, buildUserMessage } from "./prompt";
import type { Mood } from "./types";

export const MODEL = "claude-haiku-5-5";

export interface LLM {
  improve(text: string, mood: Mood): Promise<string>;
}

export class UpstreamError extends Error {
  constructor(public readonly reason: string) {
    super(reason);
    this.name = "UpstreamError";
  }
}

export type MessagesClient = Pick<Anthropic, "messages">;

function stripWrapper(s: string): string {
  return s.replace(/^<texto>\s*/, "").replace(/\s*<\/texto>$/, "").trim();
}

export class AnthropicLLM implements LLM {
  constructor(private readonly client: MessagesClient) {}

  async improve(text: string, mood: Mood): Promise<string> {
    let response: Anthropic.Message;
    try {
      response = await this.client.messages.create({
        model: MODEL,
        max_tokens: 1024,
        thinking: { type: "disabled" },
        output_config: { effort: "low" },
        system: buildSystemPrompt(mood),
        messages: [{ role: "user", content: buildUserMessage(text) }],
      });
    } catch (err) {
      throw new UpstreamError(err instanceof Anthropic.APIError ? `api_${err.status ?? "unknown"}` : "network");
    }
    if (response.stop_reason === "refusal") throw new UpstreamError("refusal");
    if (response.stop_reason === "max_tokens") throw new UpstreamError("max_tokens");
    const raw = response.content
      .filter((b): b is Anthropic.TextBlock => b.type === "text")
      .map((b) => b.text)
      .join("");
    const out = stripWrapper(raw.trim());
    if (!out) throw new UpstreamError("empty");
    return out;
  }
}
