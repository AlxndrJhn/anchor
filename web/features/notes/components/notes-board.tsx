"use client";

import * as React from "react";
import { Skeleton } from "@/components/ui/skeleton";
import { useTagMap } from "@/features/tags/hooks";
import { useDelayedFlag } from "@/lib/hooks/use-delayed-flag";
import { cn } from "@/lib/utils";
import { useMasonry } from "../hooks/use-masonry";
import type { Note } from "../types";
import { type CardDrag, type CardLayout, NoteCard } from "./note-card";

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
   * Makes cards draggable within their group ("Custom" sort): the note was
   * dropped before or after the target.
   */
  onMove?: (noteId: string, targetId: string, side: "before" | "after") => void;
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
      onMove,
    },
    ref,
  ) => {
    const isList = layout === "list";
    const tagMap = useTagMap();
    const boardRef = React.useRef<HTMLDivElement>(null);
    const rulerRef = React.useRef<HTMLDivElement>(null);
    React.useImperativeHandle(ref, () => boardRef.current as HTMLDivElement);
    useMasonry(boardRef, rulerRef);
    const drag = useCardDrag(isList, onMove);
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
            <div className={cn("cards", layout, picking && "picking")}>
              {group.notes.map((note) => (
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
                  drag={drag.handlersFor(group.key)}
                  dropSide={
                    drag.drop?.id === note.id ? drag.drop.side : undefined
                  }
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

/** One set of drag handlers per group, kept stable so cards don't redraw. */
function useCardDrag(
  isList: boolean,
  onMove: NotesBoardProps["onMove"],
): {
  handlersFor: (group: string) => CardDrag | undefined;
  drop: { id: string; side: "before" | "after" } | null;
} {
  const [drop, setDrop] = React.useState<{
    id: string;
    side: "before" | "after";
  } | null>(null);
  const dragging = React.useRef<{ id: string; group: string } | null>(null);
  const onMoveRef = React.useRef(onMove);
  onMoveRef.current = onMove;
  const isListRef = React.useRef(isList);
  isListRef.current = isList;
  const cache = React.useRef(new Map<string, CardDrag>());
  const enabled = !!onMove;

  const cardOf = (e: React.DragEvent<HTMLElement>) => ({
    id: e.currentTarget.dataset.flip ?? "",
    group: e.currentTarget.dataset.dragGroup ?? "",
  });
  const sideOf = (e: React.DragEvent<HTMLElement>): "before" | "after" => {
    const box = e.currentTarget.getBoundingClientRect();
    return isListRef.current
      ? e.clientY < box.top + box.height / 2
        ? "before"
        : "after"
      : e.clientX < box.left + box.width / 2
        ? "before"
        : "after";
  };
  const make = (group: string): CardDrag => ({
    group,
    onDragStart: (e) => {
      const card = cardOf(e);
      dragging.current = card;
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/x-anchor-note", card.id);
      e.currentTarget.dataset.dragging = "";
    },
    onDragOver: (e) => {
      const from = dragging.current;
      const card = cardOf(e);
      if (!from || from.group !== card.group || from.id === card.id) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
      const side = sideOf(e);
      setDrop((was) =>
        was?.id === card.id && was.side === side ? was : { id: card.id, side },
      );
    },
    onDrop: (e) => {
      const from = dragging.current;
      const card = cardOf(e);
      if (!from || from.group !== card.group || from.id === card.id) return;
      e.preventDefault();
      onMoveRef.current?.(from.id, card.id, sideOf(e));
      dragging.current = null;
      setDrop(null);
    },
    onDragEnd: (e) => {
      delete e.currentTarget.dataset.dragging;
      dragging.current = null;
      setDrop(null);
    },
  });

  const handlersFor = (group: string) => {
    if (!enabled) return undefined;
    let found = cache.current.get(group);
    if (!found) {
      found = make(group);
      cache.current.set(group, found);
    }
    return found;
  };
  return { handlersFor, drop };
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
