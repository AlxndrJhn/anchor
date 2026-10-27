"use client";

import * as React from "react";
import type { Tag } from "./types";
import { moveItem } from "./utils";

interface Drag {
  id: string;
  from: number;
  to: number;
  /** The rows' middles when the drag began, top to bottom. */
  middles: number[];
}

/** Where a row dragged from [from] lands, with the pointer at [y]. */
export function dropIndex(middles: readonly number[], from: number, y: number) {
  return middles.filter((middle, i) => i !== from && middle < y).length;
}

/**
 * Dragging tags by their handles into a new order: [shown] follows the drag,
 * and [onReorder] gets the new order once the tag is let go. The arrow keys
 * move a focused handle's tag by one.
 */
export function useTagReorder(
  tags: readonly Tag[],
  onReorder: (ids: string[]) => void,
) {
  const [drag, setDrag] = React.useState<Drag | null>(null);
  const shown = drag ? moveItem(tags, drag.from, drag.to) : tags;
  const ids = tags.map((t) => t.id);

  const finish = (to: number, from: number) => {
    setDrag(null);
    if (to !== from) onReorder(moveItem(ids, from, to));
  };

  const handleProps = (tag: Tag) => ({
    "data-dragging": drag?.id === tag.id || undefined,
    onPointerDown: (event: React.PointerEvent<HTMLElement>) => {
      if (event.button !== 0) return;
      const from = ids.indexOf(tag.id);
      const list = event.currentTarget.closest("[data-tag-list]");
      if (from < 0 || !list) return;
      event.preventDefault();
      event.currentTarget.setPointerCapture(event.pointerId);
      const middles = [...list.querySelectorAll("[data-tag-row]")].map(
        (row) => {
          const rect = row.getBoundingClientRect();
          return rect.top + rect.height / 2;
        },
      );
      setDrag({ id: tag.id, from, to: from, middles });
    },
    onPointerMove: (event: React.PointerEvent<HTMLElement>) => {
      if (drag?.id !== tag.id) return;
      const to = dropIndex(drag.middles, drag.from, event.clientY);
      if (to !== drag.to) setDrag({ ...drag, to });
    },
    onPointerUp: () => {
      if (drag?.id === tag.id) finish(drag.to, drag.from);
    },
    onPointerCancel: () => setDrag(null),
    onKeyDown: (event: React.KeyboardEvent<HTMLElement>) => {
      const step =
        event.key === "ArrowUp" ? -1 : event.key === "ArrowDown" ? 1 : 0;
      if (!step) return;
      event.preventDefault();
      const from = ids.indexOf(tag.id);
      const to = from + step;
      if (from >= 0 && to >= 0 && to < ids.length) finish(to, from);
    },
  });

  return { shown, handleProps, draggingId: drag?.id ?? null };
}
