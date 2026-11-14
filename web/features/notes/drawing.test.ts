import { describe, expect, it } from "vitest";
import {
  addPoint,
  type DrawPoint,
  drawingName,
  fontSize,
  hasInk,
  type Stroke,
  strokeWidth,
} from "./drawing";

const stroke = (tool: Stroke["tool"], points: DrawPoint[] = []): Stroke => ({
  tool,
  color: "#000",
  size: 0.01,
  points,
});

describe("drawing", () => {
  it("skips points too close to the last one", () => {
    const points: DrawPoint[] = [];
    expect(addPoint(points, { x: 0.1, y: 0.1, pressure: 0.5 })).toBe(true);
    expect(addPoint(points, { x: 0.1001, y: 0.1, pressure: 0.5 })).toBe(false);
    expect(addPoint(points, { x: 0.12, y: 0.1, pressure: 0.5 })).toBe(true);
    expect(points).toHaveLength(2);
  });

  it("has ink only when something isn't erasing", () => {
    expect(hasInk([])).toBe(false);
    expect(hasInk([stroke("eraser", [{ x: 0, y: 0, pressure: 0.5 }])])).toBe(
      false,
    );
    expect(hasInk([stroke("pen", [{ x: 0, y: 0, pressure: 0.5 }])])).toBe(true);
  });

  it("counts words and emojis as ink, but not blank text", () => {
    const text = { color: "#000", size: 0.01, x: 0.1, y: 0.1 };
    expect(hasInk([{ ...text, tool: "text", text: "  " }])).toBe(false);
    expect(hasInk([{ ...text, tool: "text", text: "Hi" }])).toBe(true);
    expect(hasInk([{ ...text, tool: "emoji", text: "🌳" }])).toBe(true);
  });

  it("makes an emoji twice as big as text of the same size", () => {
    expect(fontSize({ tool: "text", size: 0.01 })).toBeCloseTo(0.05);
    expect(fontSize({ tool: "emoji", size: 0.01 })).toBeCloseTo(0.1);
  });

  it("widens a pen with pressure, and a marker always", () => {
    expect(strokeWidth(stroke("pen"), 0.5)).toBeCloseTo(0.01);
    expect(strokeWidth(stroke("pen"), 1)).toBeCloseTo(0.015);
    expect(strokeWidth(stroke("marker"), 1)).toBeCloseTo(0.03);
  });

  it("names a drawing for the moment it was made", () => {
    expect(drawingName(new Date(2026, 10, 14, 9, 5, 3, 7))).toBe(
      "Drawing 2026-11-14-09-05-03-007.png",
    );
  });
});
