import { describe, expect, it } from "vitest";
import { deltaToBlocks } from "./note-blocks";
import { inkFor, isFont, isHexColor, toHexColor } from "./text-style";

describe("text styles", () => {
  it("stores colours as lowercase #rrggbb", () => {
    expect(toHexColor("#ABC")).toBe("#aabbcc");
    expect(toHexColor("#E03131")).toBe("#e03131");
    expect(toHexColor("rgb(224, 49, 49)")).toBe("#e03131");
    expect(toHexColor("red")).toBeNull();
    expect(isHexColor("#e03131")).toBe(true);
    expect(isHexColor("yellow")).toBe(false);
  });

  it("picks an ink that reads on a highlight", () => {
    expect(inkFor("#feea74")).toBe("#1a1a1a");
    expect(inkFor("#1971c2")).toBe("#ffffff");
  });

  it("knows the fonts both apps have", () => {
    expect(isFont("serif")).toBe(true);
    expect(isFont("monospace")).toBe(true);
    expect(isFont("comic")).toBe(true);
    expect(isFont("marker")).toBe(true);
    expect(isFont("comic sans")).toBe(false);
  });

  it("shows colours, fonts and picked highlights on cards", () => {
    const [block] = deltaToBlocks(
      JSON.stringify({
        ops: [
          { insert: "red", attributes: { color: "#e03131" } },
          { insert: "serif", attributes: { font: "serif" } },
          { insert: "picked", attributes: { highlight: "#ffaa00" } },
          { insert: "odd", attributes: { color: "red", font: "papyrus" } },
          { insert: "\n" },
        ],
      }),
    );
    expect(block.runs.map(({ text, ...style }) => [text, style])).toEqual([
      ["red", expect.objectContaining({ color: "#e03131" })],
      ["serif", expect.objectContaining({ font: "serif" })],
      ["picked", expect.objectContaining({ highlight: "#ffaa00" })],
      ["odd", expect.objectContaining({ color: undefined, font: undefined })],
    ]);
  });
});
