import Delta, { type Op } from "quill-delta";
import { describe, expect, it } from "vitest";
import { parseStoredContent, type QuillDelta, type QuillOp } from "./quill";
import {
  checkboxesAction,
  createHideCheckboxesDelta,
  createShowCheckboxesDelta,
  toggleChecklistItem,
} from "./quill-checklist";
import { deltaToLines, getLineText } from "./quill-lines";

// Adjacent ops merged.
const norm = (ops: QuillOp[]) =>
  (ops as Op[]).reduce((d, op) => d.push(op), new Delta()).ops;
const apply = (base: QuillDelta, change: QuillDelta) =>
  norm(
    new Delta(base.ops as Op[]).compose(new Delta(change.ops as Op[]))
      .ops as QuillOp[],
  );

describe("toggleChecklistItem", () => {
  const stored = JSON.stringify({
    ops: [
      { insert: "Eggs" },
      { insert: "\n", attributes: { list: "unchecked" } },
      { insert: "Milk" },
      { insert: "\n", attributes: { list: "unchecked" } },
      { insert: "Done" },
      { insert: "\n", attributes: { list: "checked" } },
    ],
  });
  const items = (content: string | null) =>
    deltaToLines(parseStoredContent(content).ops).map(
      (l) => `${getLineText(l)}:${l.newlineOp.attributes?.list}`,
    );

  it("ticks an item in place", () => {
    expect(items(toggleChecklistItem(stored, 0, false))).toEqual([
      "Eggs:checked",
      "Milk:unchecked",
      "Done:checked",
    ]);
  });

  it("moves a ticked item to the bottom when sorting is on", () => {
    expect(items(toggleChecklistItem(stored, 0, true))).toEqual([
      "Milk:unchecked",
      "Done:checked",
      "Eggs:checked",
    ]);
  });

  it("unticks a ticked item", () => {
    expect(items(toggleChecklistItem(stored, 2, false))[2]).toBe(
      "Done:unchecked",
    );
  });

  it("ignores lines that aren't checklist items", () => {
    expect(
      toggleChecklistItem(
        JSON.stringify({ ops: [{ insert: "a\n" }] }),
        0,
        false,
      ),
    ).toBeNull();
  });
});

describe("show and hide checkboxes", () => {
  const note: QuillDelta = {
    ops: [
      { insert: "Groceries" },
      { insert: "\n", attributes: { header: 2 } },
      { insert: "Milk" },
      { insert: "\n", attributes: { list: "checked" } },
      { insert: "\nEggs" },
      { insert: "\n", attributes: { list: "bullet", indent: 1 } },
    ],
  };

  it("makes every written line an unchecked item", () => {
    expect(checkboxesAction(note)).toBe("show");
    const after: QuillDelta = {
      ops: apply(
        note,
        createShowCheckboxesDelta(note) as QuillDelta,
      ) as QuillOp[],
    };
    expect(after.ops).toEqual(
      norm([
        { insert: "Groceries" },
        { insert: "\n", attributes: { list: "unchecked" } },
        { insert: "Milk" },
        { insert: "\n", attributes: { list: "checked" } },
        { insert: "\nEggs" },
        { insert: "\n", attributes: { list: "unchecked", indent: 1 } },
      ]),
    );
    expect(checkboxesAction(after)).toBe("hide");
  });

  it("hide turns the items back into plain lines", () => {
    const list: QuillDelta = {
      ops: [
        { insert: "Milk" },
        { insert: "\n", attributes: { list: "checked" } },
      ],
    };
    expect(apply(list, createHideCheckboxesDelta(list) as QuillDelta)).toEqual(
      norm([{ insert: "Milk\n" }]),
    );
  });
});
