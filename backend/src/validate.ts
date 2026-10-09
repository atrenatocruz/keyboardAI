import { isMood, type Mood } from "./types";

export const MAX_TEXT_LENGTH = 1000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const segmenter = new Intl.Segmenter("pt-PT", { granularity: "grapheme" });

export type ValidationResult =
  | { ok: true; value: { installId: string; text: string; mood: Mood } }
  | { ok: false };

export function graphemeLength(s: string): number {
  let n = 0;
  for (const _ of segmenter.segment(s)) n++;
  return n;
}

export function validateRequest(installId: string | null, body: unknown): ValidationResult {
  if (!installId || !UUID_RE.test(installId)) return { ok: false };
  if (typeof body !== "object" || body === null) return { ok: false };
  const { text, mood } = body as Record<string, unknown>;
  if (typeof text !== "string" || text.trim().length === 0) return { ok: false };
  if (graphemeLength(text) > MAX_TEXT_LENGTH) return { ok: false };
  if (!isMood(mood)) return { ok: false };
  return { ok: true, value: { installId: installId.toLowerCase(), text, mood } };
}
