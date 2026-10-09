import { describe, expect, it, vi } from "vitest";
import { AnthropicLLM, MODEL, UpstreamError, type MessagesClient } from "../src/llm";
import { buildSystemPrompt, buildUserMessage } from "../src/prompt";

function fakeClient(response: unknown) {
  const create = vi.fn().mockResolvedValue(response);
  return { client: { messages: { create } } as unknown as MessagesClient, create };
}

const msg = (text: string, stop_reason = "end_turn") => ({
  content: [{ type: "text", text }],
  stop_reason,
});

describe("AnthropicLLM", () => {
  it("calls Haiku with the mood prompt and returns trimmed text", async () => {
    const { client, create } = fakeClient(msg("  Boas! Consegues mandar-me isso?  "));
    const out = await new AnthropicLLM(client).improve("boas, consegues me mandar isso?", "natural");
    expect(out).toBe("Boas! Consegues mandar-me isso?");
    const params = create.mock.calls[0][0];
    expect(params.model).toBe(MODEL);
    expect(MODEL).toBe("claude-haiku-5-5");
    expect(params.thinking).toEqual({ type: "disabled" });
    expect(params.output_config).toEqual({ effort: "low" });
    expect(params.temperature).toBeUndefined();
    expect(params.system).toBe(buildSystemPrompt("natural"));
    expect(params.messages).toEqual([
      { role: "user", content: buildUserMessage("boas, consegues me mandar isso?") },
    ]);
  });

  it("strips <texto> wrapper if the model echoes it", async () => {
    const { client } = fakeClient(msg("<texto>\nOlá!\n</texto>"));
    expect(await new AnthropicLLM(client).improve("ola", "direto")).toBe("Olá!");
  });

  it("throws UpstreamError on refusal, truncation or empty output", async () => {
    for (const r of [msg("x", "refusal"), msg("x", "max_tokens"), msg("   ")]) {
      const { client } = fakeClient(r);
      await expect(new AnthropicLLM(client).improve("ola", "natural")).rejects.toBeInstanceOf(UpstreamError);
    }
  });

  it("wraps client errors in UpstreamError", async () => {
    const create = vi.fn().mockRejectedValue(new Error("socket hang up"));
    const client = { messages: { create } } as unknown as MessagesClient;
    await expect(new AnthropicLLM(client).improve("ola", "natural")).rejects.toBeInstanceOf(UpstreamError);
  });
});
