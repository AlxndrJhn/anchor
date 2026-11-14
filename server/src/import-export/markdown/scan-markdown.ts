import { escapeInlineText } from './delta-to-markdown';
import { QuillOp } from './delta-lines';

/**
 * A scanned document placed in a note's text: `{"insert": {"scan": "<json>"}}`
 * (web/features/notes/scans.ts). Each page names its original photo, an
 * attachment of the note; like the pictures placed in the text, those are
 * written with the note's other attachments, so the scan itself becomes a
 * line naming it and its page count.
 */
export const SCAN_EMBED = 'scan';

export function scanOf(op: QuillOp): string | null {
  const insert = op.insert;
  if (!insert || typeof insert !== 'object') return null;
  const value = (insert as Record<string, unknown>)[SCAN_EMBED];
  return value === undefined ? null : typeof value === 'string' ? value : '';
}

/** The line a scan is written as; null when it can't be read. */
export function scanToMarkdown(value: string): string | null {
  let data: unknown;
  try {
    data = JSON.parse(value);
  } catch {
    return null;
  }
  if (!data || typeof data !== 'object') return null;
  const { title, pages } = data as { title?: unknown; pages?: unknown };
  const count = Array.isArray(pages)
    ? pages.filter((p) => p && typeof (p as { id?: unknown }).id === 'string')
        .length
    : 0;
  if (!count) return null;
  const name =
    typeof title === 'string' && title.trim() ? title.trim() : 'Scan';
  return `**${escapeInlineText(name)}** (${count === 1 ? '1 page' : `${count} pages`})`;
}
