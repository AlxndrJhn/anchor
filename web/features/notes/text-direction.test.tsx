// @vitest-environment jsdom
import { act } from "react";
import { createRoot } from "react-dom/client";
import { describe, expect, it } from "vitest";
import { NoteBody } from "./components/note-body";
import { deltaToBlocks } from "./note-blocks";
import { registerNoteFormats } from "./quill-formats";

// React's act() warns without it.
(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;

const content = JSON.stringify({
  ops: [
    { insert: "שלום, עולם!\nTitle" },
    { insert: "\n", attributes: { header: 1 } },
    { insert: "חלב" },
    { insert: "\n", attributes: { list: "unchecked" } },
    { insert: "quote" },
    { insert: "\n", attributes: { blockquote: true } },
    { insert: "const a = 1;" },
    { insert: "\n", attributes: { "code-block": "plain" } },
  ],
});

describe("text direction", () => {
  it("lets each editor line pick its own direction, except code", async () => {
    const { Quill } = await import("react-quill-new");
    registerNoteFormats(
      Quill as unknown as Parameters<typeof registerNoteFormats>[0],
    );
    const host = document.createElement("div");
    document.body.append(host);
    const quill = new Quill(host);
    quill.setContents(JSON.parse(content).ops);
    const root = quill.root;
    for (const tag of ["p", "h1", "li", "blockquote"])
      expect(root.querySelector(tag)?.getAttribute("dir")).toBe("auto");
    expect(root.querySelector(".ql-code-block")?.hasAttribute("dir")).toBe(
      false,
    );

    // A line split off by Enter keeps it.
    quill.insertText(2, "\n");
    expect(root.querySelectorAll("p[dir=auto]")).toHaveLength(2);
    host.remove();
  });

  it("lets each card block pick its own direction from its text", () => {
    const host = document.createElement("div");
    const root = createRoot(host);
    act(() =>
      root.render(<NoteBody blocks={deltaToBlocks(content)} variant="card" />),
    );
    for (const tag of ["p", "li", "blockquote"])
      expect(host.querySelector(tag)?.getAttribute("dir")).toBe("auto");
    // The English "Not checked:" label must not set a Hebrew item's direction.
    expect(host.querySelector("li .sr-only")?.getAttribute("dir")).toBe("ltr");
    act(() => root.unmount());
  });
});
