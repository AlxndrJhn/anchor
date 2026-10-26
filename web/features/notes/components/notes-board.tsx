"use client";

import * as React from "react";
import { Skeleton } from "@/components/ui/skeleton";
import { useTagMap } from "@/features/tags/hooks";
import { useDelayedFlag } from "@/lib/hooks/use-delayed-flag";
import { cn } from "@/lib/utils";
import { type DragPreview, useCardDrag } from "../hooks/use-card-drag";
import { useMasonry } from "../hooks/use-masonry";
import type { Note } from "../types";
import { type CardLayout, NoteCard } from "./note-card";

interface NotesBoardGroup {
  key: string;
  label?: string;
  icon?: React.ReactNode;
  notes: Note[];
}

interface NotesBoardProps {
  groups: NotesBoardGroup[];
  layout: CardLayout;
  picking: boolean;
  picked: Set<string>;
  /** Leave out for cards that can't be picked. */
  onPick?: (noteId: string, range: boolean) => void;
  onShare?: (note: Note) => void;
  /** Keep it stable, or every card redraws. */
  renderActions?: (note: Note) => React.ReactNode;
  dateLabel?: (note: Note) => string;
  /** The search the notes were found by. */
  searchTerm?: string;
  /**
   * Lets cards be dragged to new places within their group, as in Google
   * Keep; called with the group's new order when one is let go.
   */
  onReorder?: (draggedId: string, ids: string[]) => void;
}

export const NotesBoard = React.forwardRef<HTMLDivElement, NotesBoardProps>(
  (
    {
      groups,
      layout,
      picking,
      picked,
      onPick,
      onShare,
      renderActions,
      dateLabel,
      searchTerm,
      onReorder,
    },
    ref,
  ) => {
    const isList = layout === "list";
    const tagMap = useTagMap();
    const boardRef = React.useRef<HTMLDivElement>(null);
    const rulerRef = React.useRef<HTMLDivElement>(null);
    React.useImperativeHandle(ref, () => boardRef.current as HTMLDivElement);
    useMasonry(boardRef, rulerRef);
    const drag = useCardDrag({
      enabled: !!onReorder && !picking,
      onDrop: (draggedId, ids) => onReorder?.(draggedId, ids),
    });
    return (
      <div
        ref={boardRef}
        data-hold-width
        className="relative grid min-w-0 gap-3.5"
      >
        <div
          ref={rulerRef}
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 top-0 h-0"
        />
        {groups.map((group) => (
          <React.Fragment key={group.key}>
            {group.label && (
              <h2
                data-flip={`grp:${group.key}`}
                className={cn(
                  "m-0 mt-1.5 flex items-center gap-1.5 px-0.5 text-label text-muted-foreground uppercase [&+div]:-mt-1 [&_svg]:size-3.25",
                  isList && "w-full max-w-195 justify-self-center",
                )}
              >
                {group.icon}
                {group.label}
                <span className="ml-0.5 font-medium tracking-normal tabular-nums">
                  {group.notes.length}
                </span>
              </h2>
            )}
            <div
              className={cn("cards", layout, picking && "picking")}
              // A card is a link; the browser's own link dragging would take
              // the pointer away from ours.
              onDragStart={drag.enabled ? (e) => e.preventDefault() : undefined}
              onPointerDown={(e) =>
                drag.onPointerDown(
                  e,
                  group.key,
                  group.notes.map((n) => n.id),
                )
              }
            >
              {inPreviewOrder(group, drag.preview).map((note) => (
                <NoteCard
                  key={note.id}
                  note={note}
                  tagMap={tagMap}
                  layout={layout}
                  picking={picking}
                  picked={picked.has(note.id)}
                  onPick={onPick}
                  onShare={onShare}
                  renderActions={renderActions}
                  dateLabel={dateLabel?.(note)}
                  searchTerm={searchTerm}
                />
              ))}
            </div>
          </React.Fragment>
        ))}
      </div>
    );
  },
);
NotesBoard.displayName = "NotesBoard";

/** A group's notes in the order a drag is showing, if one is under way. */
function inPreviewOrder(
  group: NotesBoardGroup,
  preview: DragPreview | null,
): Note[] {
  if (!preview || preview.group !== group.key) return group.notes;
  const byId = new Map(group.notes.map((n) => [n.id, n]));
  const shown = preview.ids.flatMap((id) => byId.get(id) ?? []);
  // A note that arrived during the drag goes at the end.
  for (const note of group.notes)
    if (!preview.ids.includes(note.id)) shown.push(note);
  return shown;
}

export function NotesBoardSkeleton({ loading }: { loading: boolean }) {
  const shown = useDelayedFlag(loading);
  if (!shown) return null;
  return (
    <div
      role="status"
      aria-label="Loading notes"
      className="columns-[4_200px] gap-x-4"
    >
      {[5, 3, 4, 2, 4, 3, 5, 2].map((lines, index) => (
        <div
          key={index}
          className="mb-4 grid break-inside-avoid gap-2 rounded-card bg-card p-4 shadow-[inset_0_0_0_1px_color-mix(in_srgb,var(--border)_60%,transparent)]"
        >
          <Skeleton className="h-3.5 w-[62%] bg-[linear-gradient(90deg,var(--muted)_30%,color-mix(in_srgb,var(--muted)_40%,var(--card))_50%,var(--muted)_70%)]" />
          {Array.from({ length: lines }, (_, i) => (
            <Skeleton
              key={i}
              className="bg-[linear-gradient(90deg,var(--muted)_30%,color-mix(in_srgb,var(--muted)_40%,var(--card))_50%,var(--muted)_70%)]"
            />
          ))}
        </div>
      ))}
    </div>
  );
}
