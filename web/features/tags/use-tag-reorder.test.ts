import { describe, expect, it } from "vitest";
import { dropIndex } from "./use-tag-reorder";
import { moveItem, orderTags } from "./utils";

describe("orderTags", () => {
  it("puts dragged tags first, in their order, then the rest by name", () => {
    const ordered = orderTags([
      { name: "work", position: null },
      { name: "home", position: 1 },
      { name: "ideas" },
      { name: "zoo", position: 0 },
    ]);
    expect(ordered.map((t) => t.name)).toEqual([
      "zoo",
      "home",
      "ideas",
      "work",
    ]);
  });
});

describe("dragging a tag", () => {
  // Rows 32 px high, their middles at 16, 48, 80, 112.
  const middles = [16, 48, 80, 112];

  it("lands below the rows whose middles it passed", () => {
    expect(dropIndex(middles, 0, 10)).toBe(0);
    expect(dropIndex(middles, 0, 60)).toBe(1);
    expect(dropIndex(middles, 0, 200)).toBe(3);
    expect(dropIndex(middles, 3, 20)).toBe(1);
    expect(dropIndex(middles, 3, 0)).toBe(0);
  });

  it("moves one item", () => {
    expect(moveItem(["a", "b", "c", "d"], 3, 1)).toEqual(["a", "d", "b", "c"]);
    expect(moveItem(["a", "b", "c"], 0, 2)).toEqual(["b", "c", "a"]);
  });
});
