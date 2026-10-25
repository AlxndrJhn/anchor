import { describe, expect, it } from "vitest";
import { noteToPlainText } from "./note-text";

const content = (ops: object[]) => JSON.stringify({ ops });

describe("noteToPlainText", () => {
  it("writes checklists, bullets and numbers as text", () => {
    expect(
      noteToPlainText(
        "Trip",
        content([
          { insert: "Pack" },
          { insert: "\n" },
          { insert: "Socks" },
          { insert: "\n", attributes: { list: "checked" } },
          { insert: "Hat" },
          { insert: "\n", attributes: { list: "unchecked", indent: 1 } },
          { insert: "One" },
          { insert: "\n", attributes: { list: "ordered" } },
          { insert: "Two" },
          { insert: "\n", attributes: { list: "ordered" } },
          { insert: "Dot" },
          { insert: "\n", attributes: { list: "bullet" } },
        ]),
      ),
    ).toBe("Trip\n\nPack\n☑ Socks\n  ☐ Hat\n1. One\n2. Two\n• Dot");
  });

  it("leaves out an empty title or body", () => {
    expect(noteToPlainText("", content([{ insert: "Hi\n" }]))).toBe("Hi");
    expect(noteToPlainText("Only", null)).toBe("Only");
  });
});
