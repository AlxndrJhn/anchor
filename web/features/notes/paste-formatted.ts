import { encodeInlineImage } from "./inline-images";

/** What the clipboard holds, as Ctrl+V would paste it. */
export interface ClipboardContent {
  html?: string;
  text?: string;
  /** Pictures copied on their own, such as a screenshot. */
  pictures: File[];
}

/**
 * Reads the clipboard; the browser may ask first. Null when it can't, or
 * when it is empty.
 */
export async function readClipboard(): Promise<ClipboardContent | null> {
  const clipboard = navigator.clipboard;
  if (!clipboard) return null;
  if (typeof clipboard.read !== "function") {
    const text = await clipboard.readText().catch(() => "");
    return text ? { text, pictures: [] } : null;
  }
  const items = await clipboard.read();
  const content: ClipboardContent = { pictures: [] };
  for (const item of items) {
    for (const type of item.types) {
      if (type === "text/html" && content.html === undefined)
        content.html = await (await item.getType(type)).text();
      else if (type === "text/plain" && content.text === undefined)
        content.text = await (await item.getType(type)).text();
      else if (type.startsWith("image/")) {
        const blob = await item.getType(type);
        content.pictures.push(
          new File([blob], `pasted.${type.slice(6)}`, { type }),
        );
      }
    }
  }
  const empty =
    !content.html?.trim() && !content.text?.trim() && !content.pictures.length;
  return empty ? null : content;
}

const MARK_OPEN = "";
const MARK_CLOSE = "";
const MARKS = /(\d+)/g;

/**
 * Takes the pictures out of `html`, leaving a mark where each was, so the
 * text can be pasted while they are uploaded as the note's own pictures.
 */
export function takePictures(html: string): {
  html: string;
  sources: string[];
  /** Each picture's description, kept when it can't come along. */
  names: string[];
} {
  const doc = new DOMParser().parseFromString(html, "text/html");
  const sources: string[] = [];
  const names: string[] = [];
  for (const img of [...doc.querySelectorAll("img")]) {
    const src = img.getAttribute("src")?.trim();
    if (!src) {
      img.remove();
      continue;
    }
    const mark = doc.createTextNode(
      `${MARK_OPEN}${sources.length}${MARK_CLOSE}`,
    );
    sources.push(src);
    names.push(img.getAttribute("alt")?.trim() ?? "");
    const line = img.closest("p, li, h1, h2, h3, h4, h5, h6, td, th, pre");
    if (line) {
      // Inside a line, the picture stays where it was in it.
      img.replaceWith(mark);
      continue;
    }
    // Otherwise on a paragraph of its own, as pictures go in a note.
    const paragraph = doc.createElement("p");
    paragraph.append(mark);
    img.replaceWith(paragraph);
  }
  flattenTables(doc);
  return { html: doc.body.innerHTML, sources, names };
}

/**
 * The picture at `src`; null when the page can't fetch it. A relative
 * address belongs to the page it was copied from (Claude's pictures are
 * such), so only whole addresses are tried.
 */
export async function fetchPicture(src: string): Promise<File | null> {
  if (!/^(data|blob|https?):/i.test(src)) return null;
  try {
    const response = await fetch(src);
    if (!response.ok) return null;
    const blob = await response.blob();
    if (!blob.type.startsWith("image/")) return null;
    const name = src.startsWith("data:")
      ? `pasted.${blob.type.slice(6)}`
      : decodeURIComponent(new URL(src).pathname).split("/").pop() || "pasted";
    return new File([blob], name, { type: blob.type });
  } catch {
    return null;
  }
}

/**
 * `html` from takePictures with each mark made the note's picture `ids[n]`,
 * as Quill pastes it; a mark without one becomes its name in brackets, so
 * the place shows what was there.
 */
export function putPictures(
  html: string,
  ids: (string | null)[],
  names: string[] = [],
): string {
  return html.replace(MARKS, (_, n: string) => {
    const id = ids[Number(n)];
    if (!id) {
      const name = names[Number(n)];
      return name ? `[${escapeHtml(name)}]` : "";
    }
    const value = encodeInlineImage({ id })
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;");
    return `<span class="note-image" data-value="${value}"></span>`;
  });
}

function escapeHtml(text: string) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

/**
 * Notes have no tables, so each row becomes a line of its own, its cells
 * apart by a bar and the header row bold, rather than a line per cell.
 */
function flattenTables(doc: Document) {
  for (const table of [...doc.querySelectorAll("table")]) {
    const lines = [...table.querySelectorAll("tr")].map((row) => {
      const cells = [...row.children].filter(
        (cell) => cell.matches("td, th") && cell.textContent?.trim(),
      );
      const line = doc.createElement("p");
      cells.forEach((cell, i) => {
        if (i > 0) line.append(" | ");
        const isHeader =
          cell.tagName === "TH" && !cell.querySelector("strong, b");
        const part = doc.createElement(isHeader ? "strong" : "span");
        part.append(...cell.childNodes);
        line.append(part);
      });
      return line;
    });
    table.replaceWith(...lines.filter((line) => line.textContent));
  }
}
