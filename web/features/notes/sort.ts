import type { SortBy, SortOrder } from "@/features/preferences";
import { hasTitle } from "./title";
import type { Note } from "./types";

export type SortableNote = Pick<
  Note,
  "id" | "title" | "createdAt" | "updatedAt" | "position" | "positionedAt"
>;

/**
 * Where a note sorts in "Last edited, newest first", as in Google Keep: by
 * its last edit, unless it was dragged since, in which case where it was
 * put. Both are milliseconds, so dragged and edited notes mix.
 */
export function sortKey(
  note: Pick<Note, "updatedAt" | "position" | "positionedAt">,
): number {
  const edited = new Date(note.updatedAt).getTime();
  if (note.position == null || !note.positionedAt) return edited;
  return new Date(note.positionedAt).getTime() >= edited
    ? note.position
    : edited;
}

/**
 * The place for a note dropped between `above` and `below` (either may be
 * missing at the ends), in `sortKey` terms.
 */
export function positionBetween(
  above: SortableNote | undefined,
  below: SortableNote | undefined,
): number {
  const step = 1000;
  if (above && below) return (sortKey(above) + sortKey(below)) / 2;
  if (above) return sortKey(above) - step;
  if (below) return sortKey(below) + step;
  return Date.now();
}

export const compareNotes =
  (sortBy: SortBy, sortOrder: SortOrder) =>
  (a: SortableNote, b: SortableNote) => {
    let comparison = 0;
    if (sortBy === "title") {
      // Untitled notes come last whichever way titles are ordered.
      const aUntitled = !hasTitle(a.title);
      if (aUntitled !== !hasTitle(b.title)) return aUntitled ? 1 : -1;
      comparison = a.title.trim().localeCompare(b.title.trim());
    } else if (sortBy === "updatedAt") {
      // Newest first takes dragged places into account; oldest first is the
      // plain edit time.
      comparison =
        sortOrder === "desc"
          ? sortKey(a) - sortKey(b)
          : new Date(a.updatedAt).getTime() - new Date(b.updatedAt).getTime();
    } else if (sortBy === "createdAt") {
      comparison =
        new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
    }

    const ordered = sortOrder === "asc" ? comparison : -comparison;
    if (ordered !== 0) return ordered;
    return a.id < b.id ? 1 : a.id > b.id ? -1 : 0;
  };
