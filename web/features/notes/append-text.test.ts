import { describe, expect, it } from "vitest";
import { appendTextToContent } from "./quill";

const ops = (content: string) => JSON.parse(content).ops;

describe("appendTextToContent", () => {
  it("puts the text on new lines after what the note says", () => {
    const content = JSON.stringify({ ops: [{ insert: "Groceries\n" }] });
    expect(ops(appendTextToContent(content, "Milk\nBread"))).toEqual([
      { insert: "Groceries\nMilk\nBread\n" },
    ]);
  });

  it("starts an empty note with the text", () => {
    expect(ops(appendTextToContent(null, "Milk"))).toEqual([
      { insert: "Milk\n" },
    ]);
    expect(
      ops(
        appendTextToContent(
          JSON.stringify({ ops: [{ insert: "\n" }] }),
          "Milk",
        ),
      ),
    ).toEqual([{ insert: "Milk\n" }]);
  });

  it("keeps the note's formatting", () => {
    const content = JSON.stringify({
      ops: [{ insert: "Title", attributes: { bold: true } }, { insert: "\n" }],
    });
    expect(ops(appendTextToContent(content, "Milk"))).toEqual([
      { insert: "Title", attributes: { bold: true } },
      { insert: "\nMilk\n" },
    ]);
  });
});
