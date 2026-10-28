import { describe, expect, it } from "vitest";
import {
  blockState,
  burnFront,
  burnPattern,
  sparkOpacity,
  wholeBlocksPath,
} from "./destroy";

describe("the burn", () => {
  it("waits for the jolt, then reaches every block", () => {
    expect(burnFront(0)).toBe(0);
    expect(burnFront(0.1)).toBe(0);
    expect(burnFront(0.5)).toBeGreaterThan(0);
    expect(blockState(1, burnFront(1))).toBe("gone");
  });

  it("lets the sparks fly on past the end, fading out", () => {
    expect(burnFront(1.2)).toBeGreaterThan(burnFront(1));
    expect(sparkOpacity(1)).toBe(1);
    expect(sparkOpacity(1 + 250 / 1100)).toBeCloseTo(0.5);
    expect(sparkOpacity(1 + 500 / 1100)).toBe(0);
  });

  it("glows at the edge before a block goes", () => {
    expect(blockState(0.5, 0.3)).toBe("whole");
    expect(blockState(0.5, 0.55)).toBe("burning");
    expect(blockState(0.5, 0.9)).toBe("gone");
  });

  it("covers the card in blocks, from 0 to 1, the same for the same seed", () => {
    const pattern = burnPattern(180, 240, 7);
    expect(pattern.columns * pattern.cell).toBeGreaterThanOrEqual(180);
    expect(pattern.rows * pattern.cell).toBeGreaterThanOrEqual(240);
    expect(Math.min(...pattern.thresholds)).toBe(0);
    expect(Math.max(...pattern.thresholds)).toBe(1);
    expect(burnPattern(180, 240, 7)).toEqual(pattern);
  });

  it("clips to the whole blocks, a rectangle per run in a row", () => {
    const pattern = {
      columns: 3,
      rows: 1,
      cell: 10,
      thresholds: [0.9, 0.95, 0.1],
    };
    // Before the burn: one run across the row, cut at the card's edge.
    expect(wholeBlocksPath(pattern, 0, 25, 10)).toBe("M0 0H25V10H0Z");
    // The last block burnt through.
    expect(wholeBlocksPath(pattern, 0.5, 25, 10)).toBe("M0 0H20V10H0Z");
    // All gone: nothing shows.
    expect(wholeBlocksPath(pattern, 2, 25, 10)).toBe("M0 0Z");
  });
});
