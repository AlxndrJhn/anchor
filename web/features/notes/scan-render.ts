// Draws scan pages in the browser: reads the original photos, renders them
// with scans.ts, and makes thumbnails, JPEGs and the PDF.

import { fetchAttachmentBlob } from "./api";
import {
  buildPdf,
  type Corners,
  findPageCorners,
  PDF_JPEG_QUALITY,
  PDF_MAX_SIDE,
  type Pixels,
  pagesLabel,
  parseScan,
  pdfFileName,
  renderPage,
  type ScanDocument,
  type ScanPage,
  scanTitle,
} from "./scans";

function canvasOf(width: number, height: number) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  return canvas;
}

/** The photo upright as shown, its longest side at most `maxLong`. */
export async function readPhoto(blob: Blob, maxLong: number): Promise<Pixels> {
  const bitmap = await createImageBitmap(blob, {
    imageOrientation: "from-image",
  });
  try {
    const scale = Math.min(1, maxLong / Math.max(bitmap.width, bitmap.height));
    const width = Math.max(1, Math.round(bitmap.width * scale));
    const height = Math.max(1, Math.round(bitmap.height * scale));
    const context = canvasOf(width, height).getContext("2d", {
      willReadFrequently: true,
    });
    if (!context) throw new Error("No canvas");
    context.imageSmoothingQuality = "high";
    context.drawImage(bitmap, 0, 0, width, height);
    return context.getImageData(0, 0, width, height);
  } finally {
    bitmap.close();
  }
}

/** Looks for the page in a photo, read small and squeezed square. */
export async function detectCorners(blob: Blob): Promise<Corners | null> {
  const bitmap = await createImageBitmap(blob, {
    imageOrientation: "from-image",
  });
  try {
    const side = 320;
    const context = canvasOf(side, side).getContext("2d", {
      willReadFrequently: true,
    });
    if (!context) return null;
    context.drawImage(bitmap, 0, 0, side, side);
    return findPageCorners(context.getImageData(0, 0, side, side));
  } finally {
    bitmap.close();
  }
}

export function pixelsToCanvas(pixels: Pixels) {
  const canvas = canvasOf(pixels.width, pixels.height);
  canvas
    .getContext("2d")
    ?.putImageData(
      new ImageData(
        new Uint8ClampedArray(pixels.data),
        pixels.width,
        pixels.height,
      ),
      0,
      0,
    );
  return canvas;
}

const toBlob = (canvas: HTMLCanvasElement, type: string, quality?: number) =>
  new Promise<Blob>((resolve, reject) =>
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("No picture"))),
      type,
      quality,
    ),
  );

/** The finished page, its longest side at most `maxSide`. */
export async function renderPageFrom(
  photo: Blob,
  page: ScanPage,
  maxSide: number,
): Promise<Pixels> {
  // As the phone does: a big photo is shrunk first, so small pages aren't
  // grainy and big ones stay quick.
  const pixels = await readPhoto(photo, maxSide * 2);
  return renderPage(pixels, page, maxSide);
}

/** Key for a rendered page: the photo and everything that changes it. */
export function pageKey(page: ScanPage, maxSide: number) {
  return `${maxSide}:${JSON.stringify(page)}`;
}

const previews = new Map<string, Promise<string>>();

/** An object URL for the page drawn small; cached by its settings. */
export function pagePreview(
  load: (id: string) => Promise<Blob>,
  page: ScanPage,
  maxSide = 300,
  scope = "",
): Promise<string> {
  const key = `${scope}/${pageKey(page, maxSide)}`;
  let url = previews.get(key);
  if (!url) {
    url = load(page.id)
      .then((blob) => renderPageFrom(blob, page, maxSide))
      .then((pixels) => toBlob(pixelsToCanvas(pixels), "image/jpeg", 0.85))
      .then((blob) => URL.createObjectURL(blob));
    url.catch(() => previews.delete(key));
    previews.set(key, url);
  }
  return url;
}

/** The scan as a PDF file, laid out by its settings. */
export async function scanPdf(
  scan: ScanDocument,
  load: (id: string) => Promise<Blob>,
): Promise<File> {
  const { quality } = scan.pdf;
  const images = [];
  for (const page of scan.pages) {
    const pixels = await renderPageFrom(
      await load(page.id),
      page,
      PDF_MAX_SIDE[quality],
    );
    const jpeg = await toBlob(
      pixelsToCanvas(pixels),
      "image/jpeg",
      PDF_JPEG_QUALITY[quality],
    );
    images.push({
      jpeg: new Uint8Array(await jpeg.arrayBuffer()),
      width: pixels.width,
      height: pixels.height,
    });
  }
  const bytes = buildPdf(images, scan.pdf, scanTitle(scan));
  return new File([bytes.buffer as ArrayBuffer], pdfFileName(scan), {
    type: "application/pdf",
  });
}

export function downloadFile(file: File) {
  const url = URL.createObjectURL(file);
  const link = document.createElement("a");
  link.href = url;
  link.download = file.name;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 30_000);
}

/** Whether this browser can hand a PDF to other apps. */
export function canSharePdf() {
  if (typeof navigator === "undefined" || !navigator.canShare) return false;
  try {
    return navigator.canShare({
      files: [new File([""], "a.pdf", { type: "application/pdf" })],
    });
  } catch {
    return false;
  }
}

export async function sharePdf(file: File) {
  await navigator.share({ files: [file], title: file.name });
}

/** Draws the page thumbnails of the scans in the text that haven't been. */
export function showScans(root: HTMLElement, noteId: string) {
  for (const strip of root.querySelectorAll<HTMLElement>(
    ".scan .scan-pages:not([data-shown])",
  )) {
    strip.setAttribute("data-shown", "");
    const node = strip.closest<HTMLElement>(".scan");
    const scan = parseScan(node?.getAttribute("data-value"));
    if (!scan) continue;
    const load = (id: string) => fetchAttachmentBlob(noteId, id);
    scan.pages.slice(0, 6).forEach((page, i) => {
      const img = strip.children[i] as HTMLImageElement | undefined;
      if (!img) return;
      pagePreview(load, page, 300, noteId).then(
        (url) => {
          img.src = url;
        },
        () => img.setAttribute("data-failed", ""),
      );
    });
  }
}

/** The card's text, for the embed and screen readers. */
export function scanLabel(scan: ScanDocument) {
  return `${scanTitle(scan)}, ${pagesLabel(scan.pages.length)}`;
}
