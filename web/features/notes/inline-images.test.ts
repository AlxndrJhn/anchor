import { describe, expect, it } from "vitest";
import { attachmentKindOf } from "./constants";
import { parseInlineImage } from "./inline-images";

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
