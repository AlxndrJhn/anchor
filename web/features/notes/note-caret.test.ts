import { describe, expect, it } from "vitest";
import { clampCaret, returnCaretTo, takeReturnCaret } from "./note-caret";

describe("note caret", () => {
  it("is taken once", () => {
    returnCaretTo("n1", { field: "content", index: 4, length: 2 });
    expect(takeReturnCaret("n1")).toEqual({
      field: "content",
      index: 4,
      length: 2,
    });
    expect(takeReturnCaret("n1")).toBeNull();
  });

  it("is kept per note", () => {
    returnCaretTo("a", { field: "title", index: 1, length: 0 });
    expect(takeReturnCaret("b")).toBeNull();
    expect(takeReturnCaret("a")?.field).toBe("title");
  });

  it("fits a shorter field", () => {
    expect(clampCaret({ field: "title", index: 9, length: 3 }, 5)).toEqual({
      field: "title",
      index: 5,
      length: 0,
    });
    expect(clampCaret({ field: "content", index: 2, length: 9 }, 5)).toEqual({
      field: "content",
      index: 2,
      length: 3,
    });
  });
});
