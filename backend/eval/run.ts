import Anthropic from "@anthropic-ai/sdk";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { AnthropicLLM } from "../src/llm";
import { MOODS, type Mood } from "../src/types";

const phrases: string[] = JSON.parse(readFileSync(join(import.meta.dirname, "phrases.json"), "utf8"));
const moods: Mood[] = process.argv[2] ? [process.argv[2] as Mood] : [...MOODS];
const llm = new AnthropicLLM(new Anthropic({ timeout: 15000, maxRetries: 2 }));

const lines: string[] = [`# Eval PT-PT — ${new Date().toISOString()}`, ""];
for (const mood of moods) {
  lines.push(`## ${mood}`, "", "| # | Original | Resultado |", "|---|---|---|");
  for (const [i, text] of phrases.entries()) {
    let out: string;
    try {
      out = await llm.improve(text, mood);
    } catch (err) {
      out = `**ERRO** ${(err as Error).message}`;
    }
    const cell = (s: string) => s.replaceAll("|", "\|").replaceAll("\n", "<br>");
    lines.push(`| ${i + 1} | ${cell(text)} | ${cell(out)} |`);
    process.stdout.write(".");
  }
  lines.push("");
}
writeFileSync(join(import.meta.dirname, "report.md"), lines.join("\n"));
console.log(`\nRelatório: backend/eval/report.md (${phrases.length} frases × ${moods.length} moods)`);
