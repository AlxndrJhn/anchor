/**
 * Pictures placed in a note's text are Delta embeds that name one of the
 * note's attachments: `{"insert": {"note-image": "{\"id\":\"<id>\", ...}"}}`.
 */
export const INLINE_IMAGE_EMBED = 'note-image';

/**
 * Pages scanned with a phone: `{"insert": {"scan": "{\"pages\":[{\"id\":…}]}"}}`,
 * each page naming the attachment holding its photo.
 */
export const SCAN_EMBED = 'scan';

type Op = { insert?: unknown; attributes?: unknown };

/**
 * The content with each inline picture pointed at the attachment [ids] maps
 * its old one to. Returns it unchanged when it isn't a Delta.
 */
export function replaceAttachmentIds(
  content: string,
  ids: ReadonlyMap<string, string>,
): string {
  const parsed = parse(content);
  if (!parsed) return content;
  let changed = false;
  for (const op of parsed.ops) {
    if (replaceScanPhotos(op, ids)) changed = true;
    const embed = embedOf(op);
    const next = typeof embed?.id === 'string' ? ids.get(embed.id) : undefined;
    if (!embed || !next) continue;
    (op.insert as Record<string, unknown>)[INLINE_IMAGE_EMBED] = JSON.stringify(
      { ...embed, id: next },
    );
    changed = true;
  }
  return changed ? JSON.stringify(parsed) : content;
}

function parse(content: string | null | undefined): { ops: Op[] } | null {
  if (!content) return null;
  try {
    const json: unknown = JSON.parse(content);
    if (
      json &&
      typeof json === 'object' &&
      Array.isArray((json as { ops?: unknown }).ops)
    ) {
      return json as { ops: Op[] };
    }
  } catch {
    // Not a Delta.
  }
  return null;
}

function embedOf(op: Op): Record<string, unknown> | null {
  const insert = op.insert;
  if (!insert || typeof insert !== 'object') return null;
  const raw = (insert as Record<string, unknown>)[INLINE_IMAGE_EMBED];
  if (typeof raw !== 'string') return null;
  try {
    const data: unknown = JSON.parse(raw);
    return data && typeof data === 'object'
      ? (data as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

/** Points a scan's pages at their copied photos; true when one moved. */
function replaceScanPhotos(op: Op, ids: ReadonlyMap<string, string>): boolean {
  const insert = op.insert;
  if (!insert || typeof insert !== 'object') return false;
  const raw = (insert as Record<string, unknown>)[SCAN_EMBED];
  if (typeof raw !== 'string') return false;
  let scan: unknown;
  try {
    scan = JSON.parse(raw);
  } catch {
    return false;
  }
  const pages = (scan as { pages?: unknown } | null)?.pages;
  if (!Array.isArray(pages)) return false;
  let changed = false;
  const moved = pages.map((page: unknown) => {
    const id = (page as { id?: unknown } | null)?.id;
    const next = typeof id === 'string' ? ids.get(id) : undefined;
    if (!next) return page;
    changed = true;
    return { ...(page as object), id: next };
  });
  if (!changed) return false;
  (insert as Record<string, unknown>)[SCAN_EMBED] = JSON.stringify({
    ...(scan as object),
    pages: moved,
  });
  return true;
}
