"use client";

import * as React from "react";
import { DURATION, EASE } from "@/lib/design/tokens";
import { prefersReducedMotion } from "@/lib/motion";
import { strikeIntoPlace } from "@/lib/strike";

/** Cards glide to their new places, or strike there, as after a delete. */
export type FlipMotion = "glide" | "strike";

interface Snapshot {
  rects: Map<string, DOMRect>;
  clones: Map<string, HTMLElement>;
  motion: FlipMotion;
  at: number;
}

const NEAR_SCREEN = 200;

const isNearScreen = (rect: DOMRect) =>
  rect.bottom > -NEAR_SCREEN && rect.top < window.innerHeight + NEAR_SCREEN;

/** Call `prepare()` just before a list change; `prepare("strike")` before cards are deleted from it. */
export function useFlip<T extends HTMLElement>(
  container: React.RefObject<T | null>,
  options: { pop?: boolean } = {},
) {
  const snapshotRef = React.useRef<Snapshot | null>(null);

  const prepare = React.useCallback(
    (motion: FlipMotion = "glide") => {
      const el = container.current;
      if (!el || prefersReducedMotion()) return;
      const rects = new Map<string, DOMRect>();
      const clones = new Map<string, HTMLElement>();
      for (const item of el.querySelectorAll<HTMLElement>("[data-flip]")) {
        const key = item.dataset.flip;
        if (!key) continue;
        const rect = item.getBoundingClientRect();
        rects.set(key, rect);
        if (!isNearScreen(rect)) continue;
        const copy = item.cloneNode(true) as HTMLElement;
        copy.removeAttribute("id");
        for (const child of copy.querySelectorAll("[id]"))
          child.removeAttribute("id");
        clones.set(key, copy);
      }
      snapshotRef.current = { rects, clones, motion, at: performance.now() };
    },
    [container],
  );

  React.useLayoutEffect(() => {
    const snapshot = snapshotRef.current;
    const el = container.current;
    if (!snapshot || !el) return;
    if (performance.now() - snapshot.at > 4000) {
      snapshotRef.current = null;
      return;
    }
    const current = new Map<string, { item: HTMLElement; rect: DOMRect }>();
    for (const item of el.querySelectorAll<HTMLElement>("[data-flip]"))
      if (item.dataset.flip)
        current.set(item.dataset.flip, {
          item,
          rect: item.getBoundingClientRect(),
        });
    const sameKeys =
      current.size === snapshot.rects.size &&
      [...current.keys()].every((key) => snapshot.rects.has(key));
    const moved = [...current].some(([key, { rect }]) => {
      const oldRect = snapshot.rects.get(key);
      return (
        oldRect &&
        (Math.abs(oldRect.left - rect.left) > 0.5 ||
          Math.abs(oldRect.top - rect.top) > 0.5)
      );
    });
    if (sameKeys && !moved) return;
    snapshotRef.current = null;

    const box = el.getBoundingClientRect();
    const scrollLeft = el.scrollLeft;
    const scrollTop = el.scrollTop;
    let entering = 0;
    for (const [key, { item, rect }] of current) {
      const oldRect = snapshot.rects.get(key);
      if (oldRect && isNearScreen(oldRect)) {
        const dx = oldRect.left - rect.left;
        const dy = oldRect.top - rect.top;
        if (Math.abs(dx) <= 0.5 && Math.abs(dy) <= 0.5) continue;
        if (snapshot.motion === "strike")
          strikeIntoPlace(item, dx, dy, rect, el, {
            left: box.left,
            top: box.top,
            scrollLeft,
            scrollTop,
          });
        else
          item.animate(
            [
              { transform: `translate(${dx}px, ${dy}px)` },
              { transform: "none" },
            ],
            { duration: DURATION.move, easing: EASE.standard },
          );
      } else if (isNearScreen(rect)) {
        const delay = Math.min(entering++, 6) * 24;
        item.animate(
          [
            { opacity: 0, transform: options.pop ? "scale(.6)" : "scale(.96)" },
            { opacity: 1, transform: "none" },
          ],
          {
            duration: DURATION.move,
            delay,
            easing: options.pop ? EASE.pop : EASE.standard,
            fill: "backwards",
          },
        );
      }
    }
    for (const [key, copy] of snapshot.clones) {
      if (current.has(key)) continue;
      const oldRect = snapshot.rects.get(key);
      if (!oldRect) continue;
      Object.assign(copy.style, {
        position: "absolute",
        left: `${oldRect.left - box.left + scrollLeft}px`,
        top: `${oldRect.top - box.top + scrollTop}px`,
        width: `${oldRect.width}px`,
        height: `${oldRect.height}px`,
        margin: "0",
        pointerEvents: "none",
        zIndex: "2",
      });
      copy.setAttribute("aria-hidden", "true");
      copy.inert = true;
      el.prepend(copy);
      const animation = copy.animate(
        [
          { opacity: 1, transform: "none" },
          { opacity: 0, transform: "scale(.94)" },
        ],
        { duration: DURATION.exit, easing: EASE.exit, fill: "forwards" },
      );
      animation.onfinish = () => copy.remove();
    }
  });

  return { prepare };
}
