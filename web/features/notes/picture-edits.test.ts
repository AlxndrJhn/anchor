import { describe, expect, it } from "vitest";
import { moveArea, moveCorner } from "./components/editor/inline-image-dialogs";
import { cropPixels, pictureName, WHOLE_PICTURE } from "./picture-edits";

describe("cropPixels", () => {
  it("turns shares of the picture into pixels", () => {
    expect(
      cropPixels({ left: 0.25, top: 0.5, right: 0.75, bottom: 1 }, 400, 200),
    ).toEqual({ x: 100, y: 100, width: 200, height: 100 });
  });

  it("keeps at least one pixel, inside the picture", () => {
    expect(
      cropPixels({ left: 1, top: 1, right: 1.2, bottom: 1 }, 400, 200),
    ).toEqual({ x: 399, y: 199, width: 1, height: 1 });
  });
});

describe("crop frame", () => {
  it("moves a corner but keeps some of the picture", () => {
    expect(moveCorner(WHOLE_PICTURE, "nw", 0.3, 0.2)).toEqual({
      left: 0.3,
      top: 0.2,
      right: 1,
      bottom: 1,
    });
    const tight = moveCorner(WHOLE_PICTURE, "se", 0, 0);
    expect(tight.right).toBeCloseTo(0.05);
    expect(tight.bottom).toBeCloseTo(0.05);
  });

  it("moves the frame only as far as the picture's edge", () => {
    const area = { left: 0.2, top: 0.2, right: 0.6, bottom: 0.6 };
    const moved = moveArea(area, 0.9, -0.5);
    expect(moved.left).toBeCloseTo(0.6);
    expect(moved.right).toBeCloseTo(1);
    expect(moved.top).toBeCloseTo(0);
    expect(moved.bottom).toBeCloseTo(0.4);
  });
});

describe("pictureName", () => {
  it("names a picture by when it was made", () => {
    const at = new Date(2026, 9, 28, 14, 3, 7, 45);
    expect(pictureName("image/jpeg", at)).toBe(
      "Picture 2026-10-28-14-03-07-045.jpg",
    );
    expect(pictureName("image/png", at)).toBe(
      "Picture 2026-10-28-14-03-07-045.png",
    );
  });
});
