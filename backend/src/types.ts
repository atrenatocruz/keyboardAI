export const MOODS = ["natural", "simpatico", "profissional", "direto", "descontraido"] as const;
export type Mood = (typeof MOODS)[number];

export function isMood(value: unknown): value is Mood {
  return typeof value === "string" && (MOODS as readonly string[]).includes(value);
}
