import { describe, expect, it } from "vitest";
import {
  cropLayout,
  encodeLiveImage,
  LIVE_IMAGE_EMBED,
  liveImagesIn,
  parseLiveImage,
} from "./live-images";

describe("live images", () => {
  it("reads back what it writes", () => {
    const image = {
      id: "l1",
      source: "screen" as const,
      device: "desk",
      label: "Anchor+ on Windows",
      width: 0.5,
      crop: { left: 0.1, top: 0.2, right: 0.6, bottom: 0.9 },
    };
    expect(parseLiveImage(encodeLiveImage(image))).toEqual({
      ...image,
      camera: undefined,
    });
  });

  it("drops a crop of the whole video and a full width", () => {
    const value = encodeLiveImage({
      id: "l1",
      source: "camera",
      device: "desk",
      width: 1,
      crop: { left: 0, top: 0, right: 1, bottom: 1 },
    });
    expect(JSON.parse(value)).toEqual({
      id: "l1",
      source: "camera",
      device: "desk",
    });
  });

  it("puts a crop's sides in order and ignores one too small to show", () => {
    expect(
      parseLiveImage(
        JSON.stringify({
          id: "l1",
          device: "d",
          crop: { left: 0.8, top: 0.5, right: 0.2, bottom: 0.1 },
        }),
      )?.crop,
    ).toEqual({ left: 0.2, top: 0.1, right: 0.8, bottom: 0.5 });
    expect(
      parseLiveImage(
        JSON.stringify({
          id: "l1",
          device: "d",
          crop: { left: 0.5, top: 0, right: 0.5, bottom: 1 },
        }),
      )?.crop,
    ).toBeUndefined();
  });

  it("needs an id and the device that shows it", () => {
    expect(parseLiveImage(JSON.stringify({ id: "l1" }))).toBeNull();
    expect(parseLiveImage(JSON.stringify({ device: "d" }))).toBeNull();
    expect(parseLiveImage("{nope")).toBeNull();
    expect(parseLiveImage(undefined)).toBeNull();
  });

  it("finds the live images in stored content", () => {
    const value = encodeLiveImage({ id: "l1", source: "camera", device: "d" });
    const content = JSON.stringify({
      ops: [
        { insert: "Look\n" },
        { insert: { [LIVE_IMAGE_EMBED]: value } },
        { insert: { "note-image": '{"id":"a"}' } },
        { insert: "\n" },
      ],
    });
    expect(liveImagesIn(content).map((image) => image.id)).toEqual(["l1"]);
    expect(liveImagesIn("not json")).toEqual([]);
  });

  it("lays a cropped video out so only the crop shows", () => {
    // The right half of a 1600×900 video: 800×900.
    const layout = cropLayout(
      { left: 0.5, top: 0, right: 1, bottom: 1 },
      1600,
      900,
    );
    expect(layout.aspect).toBeCloseTo(800 / 900);
    expect(layout.width).toBe(200);
    expect(layout.height).toBe(100);
    expect(layout.left).toBe(-100);
    expect(layout.top).toBe(-0);
  });

  it("shows a whole video as it is, 16:9 until its size is known", () => {
    expect(cropLayout(undefined, 640, 480)).toMatchObject({
      aspect: 640 / 480,
      width: 100,
      height: 100,
    });
    expect(cropLayout(undefined, 0, 0).aspect).toBeCloseTo(16 / 9);
  });
});
