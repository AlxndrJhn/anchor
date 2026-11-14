import { describe, expect, it } from "vitest";
import {
  applyProfile,
  attachmentShownIn,
  buildPdf,
  type Corners,
  encodeScan,
  findPageCorners,
  isPageShape,
  makePixels,
  newScanPage,
  type Pixels,
  parseScan,
  pdfPageLayout,
  pdfText,
  renderPage,
  rotate,
  scanAttachmentIds,
  scansIn,
  straighten,
} from "./scans";

function fill(
  width: number,
  height: number,
  color: (x: number, y: number) => [number, number, number],
): Pixels {
  const p = makePixels(width, height);
  for (let y = 0; y < height; y++)
    for (let x = 0; x < width; x++) {
      const [r, g, b] = color(x, y);
      const i = (y * width + x) * 4;
      p.data[i] = r;
      p.data[i + 1] = g;
      p.data[i + 2] = b;
      p.data[i + 3] = 255;
    }
  return p;
}

const at = (p: Pixels, x: number, y: number) => {
  const i = (y * p.width + x) * 4;
  return [p.data[i], p.data[i + 1], p.data[i + 2]];
};

describe("the scan embed", () => {
  it("writes only what differs from the defaults, and reads it back", () => {
    const value = encodeScan({
      pages: [newScanPage("a")],
      pdf: { size: "a4", margin: 0, quality: "standard" },
    });
    expect(value).toBe('{"pages":[{"id":"a"}]}');
    const back = parseScan(value);
    expect(back?.pages[0]).toEqual(newScanPage("a"));
    expect(back?.pdf).toEqual({ size: "a4", margin: 0, quality: "standard" });
  });

  it("keeps every setting through a round trip", () => {
    const corners: Corners = [
      [0.12345, 0.1],
      [0.9, 0.1],
      [0.9, 0.9],
      [0.1, 0.9],
    ];
    const scan = {
      title: "Receipts",
      pages: [
        {
          ...newScanPage("a", corners),
          rotate: 90 as const,
          profile: "bw" as const,
          brightness: 10,
          contrast: -20,
          threshold: 5,
          cleanup: 80,
        },
      ],
      pdf: { size: "letter" as const, margin: 10, quality: "high" as const },
    };
    const back = parseScan(encodeScan(scan));
    expect(back?.title).toBe("Receipts");
    expect(back?.pages[0].corners?.[0][0]).toBe(0.1235);
    expect(back?.pages[0]).toMatchObject({
      rotate: 90,
      profile: "bw",
      brightness: 10,
      contrast: -20,
      threshold: 5,
      cleanup: 80,
    });
    expect(back?.pdf).toEqual(scan.pdf);
  });

  it("tolerates what it doesn't know", () => {
    const back = parseScan(
      JSON.stringify({
        pages: [
          { id: "a", profile: "sepia", brightness: 500, rotate: 85 },
          { profile: "bw" },
          { id: "b", corners: [[0, 0]] },
        ],
        pdf: { size: "a3", margin: 7, quality: "max" },
      }),
    );
    expect(back?.pages.map((p) => p.id)).toEqual(["a", "b"]);
    expect(back?.pages[0]).toMatchObject({
      profile: "text",
      brightness: 100,
      rotate: 90,
    });
    expect(back?.pages[1].corners).toBeUndefined();
    expect(back?.pdf).toEqual({ size: "a4", margin: 5, quality: "standard" });
    expect(parseScan("not json")).toBeNull();
    expect(parseScan(42)).toBeNull();
  });

  it("is found in a note's content", () => {
    const content = JSON.stringify({
      ops: [
        { insert: "Hi\n" },
        { insert: { scan: '{"pages":[{"id":"a"},{"id":"b"}]}' } },
        { insert: "\n" },
      ],
    });
    expect(scansIn(content)[0].pages).toHaveLength(2);
    expect([...scanAttachmentIds(content)]).toEqual(["a", "b"]);
    expect(scanAttachmentIds(null).size).toBe(0);
  });

  it("knows whether a photo is still shown anywhere in the text", () => {
    const ops = [
      { insert: { scan: '{"pages":[{"id":"a"}]}' } },
      { insert: { "note-image": '{"id":"b"}' } },
      { insert: "text" },
    ];
    expect(attachmentShownIn(ops, "a")).toBe(true);
    expect(attachmentShownIn(ops, "b")).toBe(true);
    expect(attachmentShownIn(ops, "c")).toBe(false);
  });
});

describe("rendering a page", () => {
  it("leaves a photo as it was in full colour with nothing changed", () => {
    const photo = fill(40, 30, (x, y) => [x * 6, y * 8, 100]);
    const page = { ...newScanPage("a"), profile: "color" as const };
    const out = renderPage(photo, page, 1200);
    expect(out.width).toBe(40);
    expect(out.height).toBe(30);
    for (const [x, y] of [
      [0, 0],
      [20, 15],
      [39, 29],
    ]) {
      const [r, g, b] = at(out, x, y);
      const [er, eg, eb] = at(photo, x, y);
      expect(Math.abs(r - er)).toBeLessThanOrEqual(1);
      expect(Math.abs(g - eg)).toBeLessThanOrEqual(1);
      expect(Math.abs(b - eb)).toBeLessThanOrEqual(1);
    }
  });

  it("turns a quarter: width and height swap, the top left goes top right", () => {
    const photo = fill(4, 2, () => [0, 0, 0]);
    photo.data.set([255, 0, 0, 255], 0);
    const turned = rotate(photo, 90);
    expect([turned.width, turned.height]).toEqual([2, 4]);
    expect(at(turned, 1, 0)).toEqual([255, 0, 0]);
    expect(at(rotate(photo, 270), 0, 3)).toEqual([255, 0, 0]);
    expect(at(rotate(photo, 180), 3, 1)).toEqual([255, 0, 0]);
  });

  it("makes black and white of only black and white", () => {
    const photo = fill(30, 30, (x, y) => {
      const v = (x * 7 + y * 3) % 256;
      return [v, (v * 2) % 256, 255 - v];
    });
    const out = applyProfile(photo, { ...newScanPage("a"), profile: "bw" });
    for (let i = 0; i < out.data.length; i += 4) {
      expect([0, 255]).toContain(out.data[i]);
      expect(out.data[i]).toBe(out.data[i + 1]);
    }
  });

  it("evens out a shadow across the paper", () => {
    // Paper going from 230 to 120 from left to right, with dark ink lines.
    const photo = fill(120, 120, (x, y) => {
      const paper = 230 - x;
      const ink = y % 20 < 2 && x % 30 < 20;
      const v = ink ? 30 : paper;
      return [v, v, v];
    });
    const out = applyProfile(photo, { ...newScanPage("a"), cleanup: 100 });
    // Paper on the shaded side comes out near white...
    expect(at(out, 110, 10)[0]).toBeGreaterThan(235);
    expect(at(out, 5, 10)[0]).toBeGreaterThan(235);
    // ...and ink stays dark.
    expect(at(out, 5, 0)[0]).toBeLessThan(80);
  });

  it("straightens a slanted page so its corners land in place", () => {
    const photo = fill(100, 100, (x) => (x < 50 ? [255, 0, 0] : [0, 0, 255]));
    const flat = straighten(photo, [
      [0.1, 0.2],
      [0.9, 0.1],
      [0.95, 0.9],
      [0.05, 0.85],
    ]);
    expect(at(flat, 2, 2)).toEqual([255, 0, 0]);
    expect(at(flat, flat.width - 3, 2)).toEqual([0, 0, 255]);
  });
});

describe("finding the page", () => {
  it("finds a tilted light page on a dark table", () => {
    const quad: Corners = [
      [0.2, 0.15],
      [0.85, 0.2],
      [0.8, 0.9],
      [0.15, 0.85],
    ];
    const inside = (px: number, py: number) => {
      let sign = 0;
      for (let i = 0; i < 4; i++) {
        const a = quad[i];
        const b = quad[(i + 1) % 4];
        const t = (b[0] - a[0]) * (py - a[1]) - (b[1] - a[1]) * (px - a[0]);
        const s = Math.sign(t);
        if (!sign) sign = s;
        else if (s && s !== sign) return false;
      }
      return true;
    };
    const photo = fill(160, 160, (x, y) =>
      inside((x + 0.5) / 160, (y + 0.5) / 160) ? [230, 228, 220] : [60, 40, 30],
    );
    const found = findPageCorners(photo);
    expect(found).not.toBeNull();
    found?.forEach(([x, y], i) => {
      expect(Math.abs(x - quad[i][0])).toBeLessThan(0.03);
      expect(Math.abs(y - quad[i][1])).toBeLessThan(0.03);
    });
    expect(isPageShape(found as Corners)).toBe(true);
  });
});

describe("the PDF", () => {
  it("puts a portrait page on A4 and a landscape one sideways", () => {
    const portrait = pdfPageLayout(1000, 1414, {
      size: "a4",
      margin: 0,
      quality: "standard",
    });
    expect(portrait.pageWidth).toBeCloseTo(595.28);
    expect(portrait.pageHeight).toBeCloseTo(841.89);
    expect(portrait.width).toBeCloseTo(595.28, 0);
    const landscape = pdfPageLayout(1414, 1000, {
      size: "letter",
      margin: 10,
      quality: "standard",
    });
    expect(landscape.pageWidth).toBe(792);
    expect(landscape.pageHeight).toBe(612);
    const margin = (10 * 72) / 25.4;
    expect(landscape.height).toBeLessThanOrEqual(612 - margin * 2 + 1e-6);
    expect(landscape.x).toBeCloseTo((792 - landscape.width) / 2);
  });

  it("sizes a fitted page from the picture", () => {
    const fit = pdfPageLayout(1500, 3000, {
      size: "fit",
      margin: 0,
      quality: "standard",
    });
    expect(fit.pageWidth).toBeCloseTo(720);
    expect(fit.pageHeight).toBeCloseTo(1440);
  });

  it("writes a PDF with a page per picture", () => {
    const jpeg = new Uint8Array([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9]);
    const pdf = buildPdf(
      [
        { jpeg, width: 10, height: 20 },
        { jpeg, width: 20, height: 10 },
      ],
      { size: "a4", margin: 0, quality: "standard" },
      "Taxes",
    );
    const text = new TextDecoder("latin1").decode(pdf);
    expect(text.startsWith("%PDF-1.4")).toBe(true);
    expect(text).toContain("/Count 2");
    expect(text).toContain("/Title (Taxes)");
    expect(pdfText("Ä(b)")).toBe("<FEFF00C4002800620029>");
    expect(pdfText("a(b)")).toBe(String.raw`(a\(b\))`);
    expect(text.trimEnd().endsWith("%%EOF")).toBe(true);
    // The table points at each object.
    const xref = Number(/startxref\n(\d+)/.exec(text)?.[1]);
    expect(text.slice(xref, xref + 4)).toBe("xref");
    const first = /xref\n0 \d+\n0000000000 65535 f \n(\d{10})/.exec(text);
    expect(text.slice(Number(first?.[1]), Number(first?.[1]) + 7)).toBe(
      "1 0 obj",
    );
  });
});
