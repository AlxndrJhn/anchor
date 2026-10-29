import { describe, expect, it } from "vitest";
import { attachmentKindOf } from "./constants";
import {
  encodeInlineImage,
  inlineImageIds,
  parseInlineImage,
  resizedWidth,
} from "./inline-images";

describe("parseInlineImage", () => {
  it("reads the picture's attachment, width and caption", () => {
    expect(
      parseInlineImage(JSON.stringify({ id: "a", width: 0.5, caption: "Cat" })),
    ).toEqual({ id: "a", width: 0.5, caption: "Cat" });
  });

  it("drops a width it can't use and a blank caption", () => {
    expect(
      parseInlineImage(JSON.stringify({ id: "a", width: 3, caption: " " })),
    ).toEqual({ id: "a", width: undefined, caption: undefined });
  });

  it("is null for anything else", () => {
    expect(parseInlineImage("not json")).toBeNull();
    expect(parseInlineImage(JSON.stringify({ width: 1 }))).toBeNull();
    expect(parseInlineImage(42)).toBeNull();
  });
});

describe("attachmentKindOf", () => {
  it("shows pictures and recordings, and keeps the rest as files", () => {
    expect(attachmentKindOf("image/png")).toBe("image");
    expect(attachmentKindOf("audio/mpeg")).toBe("audio");
    expect(attachmentKindOf("application/pdf")).toBe("file");
    expect(attachmentKindOf("image/svg+xml")).toBe("file");
  });
});

describe("encodeInlineImage", () => {
  it("writes the width to 3 decimals and leaves out what isn't set", () => {
    expect(encodeInlineImage({ id: "a", width: 0.123456 })).toBe(
      '{"id":"a","width":0.123}',
    );
    expect(encodeInlineImage({ id: "a", width: 1, caption: "  " })).toBe(
      '{"id":"a"}',
    );
    expect(encodeInlineImage({ id: "a", caption: " Cat " })).toBe(
      '{"id":"a","caption":"Cat"}',
    );
  });

  it("reads back as it was", () => {
    const image = { id: "a", width: 0.5, caption: "Cat" };
    expect(parseInlineImage(encodeInlineImage(image))).toEqual(image);
  });
});

describe("resizedWidth", () => {
  it("keeps a picture between a fifth and the full width", () => {
    expect(resizedWidth(0.05)).toBe(0.2);
    expect(resizedWidth(0.5)).toBe(0.5);
  });

  it("counts nearly the full width as all of it", () => {
    expect(resizedWidth(0.995)).toBeUndefined();
    expect(resizedWidth(1.4)).toBeUndefined();
  });
});

describe("inlineImageIds", () => {
  it("lists the pictures the text shows", () => {
    const content = JSON.stringify({
      ops: [
        { insert: "Hi\n" },
        { insert: { "note-image": '{"id":"a"}' } },
        { insert: "\n" },
        { insert: { "note-image": '{"id":"b","width":0.5}' } },
        { insert: { image: "x" } },
      ],
    });
    expect([...inlineImageIds(content)]).toEqual(["a", "b"]);
  });

  it("is empty for no content or content it can't read", () => {
    expect(inlineImageIds(null).size).toBe(0);
    expect(inlineImageIds("{").size).toBe(0);
  });
});
