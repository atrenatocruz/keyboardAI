import { describe, expect, it } from "vitest";
import { parseLimit } from "../src/config";

describe("parseLimit", () => {
  it("falls back for undefined and invalid values", () => {
    for (const v of [undefined, "", "abc", "-5", "0", "1.5"]) {
      expect(parseLimit(v, 200)).toBe(200);
    }
  });
  it("parses a positive integer", () => {
    expect(parseLimit("50", 200)).toBe(50);
  });
  it("returns the value 200 for '200'", () => {
    expect(parseLimit("200", 7)).toBe(200);
  });
});
