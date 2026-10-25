import type { SortBy, SortOrder } from "@/features/preferences";
import { hasTitle } from "./title";
import type { Note } from "./types";

export type SortableNote = Pick<
  Note,
  "id" | "title" | "createdAt" | "updatedAt" | "position"
>;

/**
 * A note's place in the "Custom" sort, highest first. Notes never dragged
 * sort by when they were made, so the order starts out newest first.
 */
export const notePosition = (note: Pick<Note, "position" | "createdAt">) =>
  note.position ?? new Date(note.createdAt).getTime();

/**
 * The place for a note dropped next to `target` in `ordered` (highest place
 * first), leaving out the dragged note itself.
 */
export function positionForDrop(
  ordered: SortableNote[],
  draggedId: string,
  targetId: string,
  side: "before" | "after",
): number | null {
  const others = ordered.filter((n) => n.id !== draggedId);
  const index = others.findIndex((n) => n.id === targetId);
  if (index < 0) return null;
  const target = notePosition(others[index]);
  const neighbour = others[side === "before" ? index - 1 : index + 1];
  const step = 1000;
  if (!neighbour) return side === "before" ? target + step : target - step;
  return (target + notePosition(neighbour)) / 2;
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
      comparison =
        new Date(a.updatedAt).getTime() - new Date(b.updatedAt).getTime();
    } else if (sortBy === "createdAt") {
      comparison =
        new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
    } else if (sortBy === "custom") {
      // Highest place first, whatever the order setting says.
      const custom = notePosition(b) - notePosition(a);
      if (custom !== 0) return custom;
    }

    const ordered = sortOrder === "asc" ? comparison : -comparison;
    if (ordered !== 0) return ordered;
    return a.id < b.id ? 1 : a.id > b.id ? -1 : 0;
  };
