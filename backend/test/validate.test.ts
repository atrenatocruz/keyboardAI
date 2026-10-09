import { describe, expect, it } from "vitest";
import { graphemeLength, MAX_TEXT_LENGTH, validateRequest } from "../src/validate";
import { isMood, MOODS } from "../src/types";

const ID = "3f2b8c1e-4a5d-4e6f-8a9b-0c1d2e3f4a5b";

describe("isMood", () => {
  it("accepts the five moods only", () => {
    expect(MOODS).toEqual(["natural", "simpatico", "profissional", "direto", "descontraido"]);
    for (const m of MOODS) expect(isMood(m)).toBe(true);
    expect(isMood("formal")).toBe(false);
    expect(isMood(undefined)).toBe(false);
  });
});

describe("graphemeLength", () => {
  it("counts user-perceived characters", () => {
    expect(graphemeLength("olá")).toBe(3);
    expect(graphemeLength("👋🏽")).toBe(1);
    expect(graphemeLength("é")).toBe(1);
  });
});

describe("validateRequest", () => {
  it("accepts a valid request and lowercases the id", () => {
    const r = validateRequest(ID.toUpperCase(), { text: "boas", mood: "natural" });
    expect(r).toEqual({ ok: true, value: { installId: ID, text: "boas", mood: "natural" } });
  });
  it("rejects missing or malformed install id", () => {
    expect(validateRequest(null, { text: "a", mood: "natural" }).ok).toBe(false);
    expect(validateRequest("abc", { text: "a", mood: "natural" }).ok).toBe(false);
  });
  it("rejects bad bodies", () => {
    expect(validateRequest(ID, null).ok).toBe(false);
    expect(validateRequest(ID, "texto").ok).toBe(false);
    expect(validateRequest(ID, { text: 5, mood: "natural" }).ok).toBe(false);
    expect(validateRequest(ID, { text: "   \n", mood: "natural" }).ok).toBe(false);
    expect(validateRequest(ID, { text: "ok", mood: "formal" }).ok).toBe(false);
  });
  it("enforces the 1000 grapheme limit", () => {
    expect(validateRequest(ID, { text: "a".repeat(MAX_TEXT_LENGTH), mood: "direto" }).ok).toBe(true);
    expect(validateRequest(ID, { text: "a".repeat(MAX_TEXT_LENGTH + 1), mood: "direto" }).ok).toBe(false);
    expect(validateRequest(ID, { text: "👋🏽".repeat(MAX_TEXT_LENGTH), mood: "direto" }).ok).toBe(true);
  });
  it("rejects huge bodies before grapheme segmentation", () => {
    expect(validateRequest(ID, { text: "a".repeat(9000), mood: "direto" }).ok).toBe(false);
  });
});
