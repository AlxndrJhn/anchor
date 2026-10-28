import { fetchAttachmentBlob } from "./api";

/**
 * A picture placed in the text (from the Android app): a Delta embed naming
 * one of the note's attachments, `{"note-image": "{\"id\":…}"}`. Its width
 * is a share of the text's width.
 */
export const INLINE_IMAGE_EMBED = "note-image";

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

const sources = new Map<string, Promise<string>>();

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
