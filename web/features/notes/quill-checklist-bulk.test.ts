import Delta, { type Op } from "quill-delta";
import { describe, expect, it } from "vitest";
import type { QuillDelta, QuillOp } from "./quill";
import {
  countCheckedItems,
  createRemoveCheckedDelta,
  createUncheckAllDelta,
} from "./quill-checklist";

const doc: QuillDelta = {
  ops: [
    { insert: "Groceries\n" },
    { insert: "Milk" },
    { insert: "\n", attributes: { list: "checked" } },
    { insert: "Eggs" },
    { insert: "\n", attributes: { list: "unchecked" } },
    { insert: "Bread" },
    { insert: "\n", attributes: { list: "checked", indent: 1 } },
    { insert: "Done\n" },
  ],
};

// Same document, adjacent ops merged.
const norm = (ops: QuillOp[]) =>
  (ops as Op[]).reduce((d, op) => d.push(op), new Delta()).ops;
const apply = (base: QuillDelta, change: QuillDelta) =>
  norm(
    new Delta(base.ops as Op[]).compose(new Delta(change.ops as Op[]))
      .ops as QuillOp[],
  );

describe("checklist bulk actions", () => {
  it("counts ticked items", () => {
    expect(countCheckedItems(doc)).toBe(2);
    expect(countCheckedItems({ ops: [{ insert: "a\n" }] })).toBe(0);
  });

  it("unticks every ticked item and keeps other formats", () => {
    const change = createUncheckAllDelta(doc);
    expect(change).not.toBeNull();
    expect(apply(doc, change as QuillDelta)).toEqual(
      norm([
        { insert: "Groceries\nMilk" },
        { insert: "\n", attributes: { list: "unchecked" } },
        { insert: "Eggs" },
        { insert: "\n", attributes: { list: "unchecked" } },
        { insert: "Bread" },
        { insert: "\n", attributes: { list: "unchecked", indent: 1 } },
        { insert: "Done\n" },
      ]),
    );
  });

  it("deletes every ticked item", () => {
    const change = createRemoveCheckedDelta(doc);
    expect(apply(doc, change as QuillDelta)).toEqual(
      norm([
        { insert: "Groceries\nEggs" },
        { insert: "\n", attributes: { list: "unchecked" } },
        { insert: "Done\n" },
      ]),
    );
  });

  it("leaves an empty line when every line was ticked", () => {
    const only: QuillDelta = {
      ops: [{ insert: "a" }, { insert: "\n", attributes: { list: "checked" } }],
    };
    expect(apply(only, createRemoveCheckedDelta(only) as QuillDelta)).toEqual([
      { insert: "\n" },
    ]);
  });

  it("returns null when nothing is ticked", () => {
    const none: QuillDelta = { ops: [{ insert: "a\n" }] };
    expect(createUncheckAllDelta(none)).toBeNull();
    expect(createRemoveCheckedDelta(none)).toBeNull();
  });
});
