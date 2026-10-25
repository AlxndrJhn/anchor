"use client";

import * as React from "react";

const NAME = "search-hit";

type HighlightRegistry = {
  set: (name: string, highlight: unknown) => void;
  delete: (name: string) => void;
};

function registry(): HighlightRegistry | null {
  const css = globalThis.CSS as { highlights?: HighlightRegistry } | undefined;
  return css?.highlights && "Highlight" in globalThis ? css.highlights : null;
}

/** Ranges of every case-insensitive match of [term] in [root]'s text. */
export function findTextRanges(root: Node, term: string): Range[] {
  const needle = term.trim().toLowerCase();
  if (!needle) return [];
  const ranges: Range[] = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    const text = (node.textContent ?? "").toLowerCase();
    for (let at = text.indexOf(needle); at !== -1; ) {
      const range = document.createRange();
      range.setStart(node, at);
      range.setEnd(node, at + needle.length);
      ranges.push(range);
      at = text.indexOf(needle, at + needle.length);
    }
  }
  return ranges;
}

/**
 * Marks [term] wherever it appears in the note text under [root] and scrolls
 * the first match into view, like a browser's find. Typing in the note ends
 * it.
 */
export function useSearchHits(
  root: React.RefObject<HTMLElement | null>,
  term: string | null,
  ready: boolean,
) {
  React.useEffect(() => {
    const host = root.current;
    const highlights = registry();
    if (!host || !term?.trim() || !ready) return;
    let scrolled = false;
    let frame = 0;
    const paint = () => {
      const text = host.querySelector(".ql-editor");
      if (!text) return;
      const ranges = findTextRanges(text, term);
      const Highlight = (
        globalThis as unknown as { Highlight: new (...r: Range[]) => unknown }
      ).Highlight;
      highlights?.set(NAME, new Highlight(...ranges));
      if (!scrolled && ranges.length) {
        scrolled = true;
        ranges[0].startContainer.parentElement?.scrollIntoView({
          block: "center",
        });
      }
    };
    const repaint = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(paint);
    };
    const observer = new MutationObserver(repaint);
    observer.observe(host, {
      childList: true,
      subtree: true,
      characterData: true,
    });
    repaint();
    const stop = () => {
      observer.disconnect();
      cancelAnimationFrame(frame);
      highlights?.delete(NAME);
    };
    host.addEventListener("beforeinput", stop, { once: true });
    return () => {
      host.removeEventListener("beforeinput", stop);
      stop();
    };
  }, [root, term, ready]);
}
