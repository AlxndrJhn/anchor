import { fetchAttachmentBlob } from "./api";

/**
 * A picture placed in the text: a Delta embed naming one of the note's
 * attachments, `{"note-image": "{\"id\":…}"}`, as the Android app writes
 * it. Its width is a share of the text's width.
 */
export const INLINE_IMAGE_EMBED = "note-image";

/** The narrowest a picture in the text can be made, as on Android. */
export const INLINE_IMAGE_MIN_WIDTH = 0.2;

export interface InlineImage {
  id: string;
  /** 0 to 1; missing for the full width. */
  width?: number;
  caption?: string;
}

export function parseInlineImage(value: unknown): InlineImage | null {
  if (typeof value !== "string") return null;
  try {
    const data = JSON.parse(value) as Partial<InlineImage> | null;
    if (!data || typeof data.id !== "string") return null;
    return {
      id: data.id,
      width:
        typeof data.width === "number" && data.width > 0 && data.width <= 1
          ? data.width
          : undefined,
      caption:
        typeof data.caption === "string" && data.caption.trim()
          ? data.caption
          : undefined,
    };
  } catch {
    return null;
  }
}

/** The embed's value, as Android writes it: width to 3 decimals, or none. */
export function encodeInlineImage(image: InlineImage): string {
  return JSON.stringify({
    id: image.id,
    ...(image.width !== undefined && image.width < 1
      ? { width: Number(image.width.toFixed(3)) }
      : {}),
    ...(image.caption?.trim() ? { caption: image.caption.trim() } : {}),
  });
}

/** The width a resize ends at: nearly the whole width counts as all of it. */
export function resizedWidth(share: number): number | undefined {
  const width = Math.min(1, Math.max(INLINE_IMAGE_MIN_WIDTH, share));
  return width >= 0.99 ? undefined : width;
}

/** The attachments a note's stored content shows in its text. */
export function inlineImageIds(content: string | null | undefined) {
  const ids = new Set<string>();
  if (!content) return ids;
  let ops: unknown;
  try {
    ops = (JSON.parse(content) as { ops?: unknown })?.ops;
  } catch {
    return ids;
  }
  if (!Array.isArray(ops)) return ids;
  for (const op of ops) {
    const insert = (op as { insert?: unknown })?.insert;
    if (!insert || typeof insert !== "object") continue;
    const image = parseInlineImage(
      (insert as Record<string, unknown>)[INLINE_IMAGE_EMBED],
    );
    if (image) ids.add(image.id);
  }
  return ids;
}

const sources = new Map<string, Promise<string>>();

/** Shows a picture just placed in the text without loading it again. */
export function primeInlineImage(noteId: string, id: string, blob: Blob) {
  sources.set(`${noteId}/${id}`, Promise.resolve(URL.createObjectURL(blob)));
}

/** Loads the pictures in the text that haven't been yet. */
export function showInlineImages(root: HTMLElement, noteId: string) {
  for (const img of root.querySelectorAll<HTMLImageElement>(
    ".note-image img:not([src])",
  )) {
    const id = img.closest<HTMLElement>(".note-image")?.dataset.id;
    if (!id) continue;
    const key = `${noteId}/${id}`;
    let source = sources.get(key);
    if (!source) {
      source = fetchAttachmentBlob(noteId, id).then((blob) =>
        URL.createObjectURL(blob),
      );
      // A failed load is tried again next time.
      source.catch(() => sources.delete(key));
      sources.set(key, source);
    }
    source.then(
      (url) => {
        if (!img.getAttribute("src")) img.src = url;
      },
      () => img.closest(".note-image")?.setAttribute("data-failed", ""),
    );
  }
}
