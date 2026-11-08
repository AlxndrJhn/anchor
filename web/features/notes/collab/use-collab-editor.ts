"use client";

import Delta, { type Op } from "quill-delta";
import { useEffect } from "react";
import type { CollabPeer, CollabSession } from "./session";

const COLORS = [
  "#c2410c",
  "#047857",
  "#1d4ed8",
  "#a21caf",
  "#b91c1c",
  "#0f766e",
  "#6d28d9",
  "#a16207",
];
const LABEL_SHOWS_MS = 2_500;

export const colorOfPeer = (id: string) => {
  let hash = 0;
  for (const character of id) {
    hash = (hash * 31 + character.charCodeAt(0)) >>> 0;
  }
  return COLORS[hash % COLORS.length];
};

interface Bounds {
  left: number;
  top: number;
  width: number;
  height: number;
}

interface QuillLike {
  container: HTMLElement;
  root: HTMLElement;
  getContents: () => { ops: unknown[] };
  getLength: () => number;
  getBounds: (index: number, length?: number) => Bounds | null;
  getLines: (index: number, length: number) => { length: () => number }[];
  getIndex: (blot: unknown) => number;
  getSelection: () => { index: number; length: number } | null;
  updateContents: (change: never, source: "api") => unknown;
  on: (event: string, handler: (...args: never[]) => void) => unknown;
  off: (event: string, handler: (...args: never[]) => void) => unknown;
}

/** Everyone else's caret and selection, drawn over the editor. */
class CursorLayer {
  private readonly layer = document.createElement("div");
  private readonly seen = new Map<string, string>();
  private readonly labelTimers = new Map<string, number>();
  private peers: CollabPeer[] = [];
  private readonly resize = new ResizeObserver(() => this.draw());

  constructor(private readonly quill: QuillLike) {
    this.layer.setAttribute("aria-hidden", "true");
    this.layer.dataset.collabCursors = "";
    Object.assign(this.layer.style, {
      position: "absolute",
      inset: "0",
      pointerEvents: "none",
      overflow: "visible",
      zIndex: "2",
    });
    const { style } = quill.container;
    if (getComputedStyle(quill.container).position === "static") {
      style.position = "relative";
    }
    quill.container.append(this.layer);
    this.resize.observe(quill.root);
  }

  setPeers(peers: CollabPeer[]) {
    this.peers = peers;
    for (const peer of peers) {
      const where = `${peer.index}:${peer.length}`;
      if (peer.index !== null && this.seen.get(peer.id) !== where) {
        this.seen.set(peer.id, where);
        this.showLabel(peer.id);
      }
    }
    this.draw();
  }

  private showLabel(id: string) {
    window.clearTimeout(this.labelTimers.get(id));
    this.labelTimers.set(
      id,
      window.setTimeout(() => {
        this.labelTimers.delete(id);
        this.draw();
      }, LABEL_SHOWS_MS),
    );
  }

  draw() {
    this.layer.replaceChildren();
    const textLength = this.quill.getLength();
    for (const peer of this.peers) {
      if (peer.index === null || !peer.canEdit) continue;
      const index = Math.min(peer.index, textLength - 1);
      const length = Math.min(peer.length, textLength - 1 - index);
      const color = colorOfPeer(peer.id);
      if (length > 0) this.drawSelection(index, length, color);
      const caret = this.quill.getBounds(index + length);
      // Inside a fold, or not laid out.
      if (!caret || caret.height === 0) continue;
      const mark = document.createElement("div");
      Object.assign(mark.style, {
        position: "absolute",
        left: `${caret.left - 1}px`,
        top: `${caret.top}px`,
        width: "2px",
        height: `${caret.height}px`,
        background: color,
        borderRadius: "1px",
      });
      mark.dataset.collabCaret = peer.id;
      if (this.labelTimers.has(peer.id)) {
        const label = document.createElement("div");
        label.textContent = peer.name;
        Object.assign(label.style, {
          position: "absolute",
          left: "0",
          bottom: "100%",
          padding: "0 5px",
          borderRadius: "4px 4px 4px 0",
          background: color,
          color: "#fff",
          font: "500 11px/16px system-ui, sans-serif",
          whiteSpace: "nowrap",
        });
        mark.append(label);
      }
      this.layer.append(mark);
    }
  }

  private drawSelection(index: number, length: number, color: string) {
    let at = index;
    let left = length;
    for (const line of this.quill.getLines(index, length)) {
      const lineStart = this.quill.getIndex(line);
      const lineEnd = lineStart + line.length();
      const part = Math.min(lineEnd - at, left);
      const bounds = part > 0 ? this.quill.getBounds(at, part) : null;
      if (bounds && bounds.height > 0) {
        const box = document.createElement("div");
        Object.assign(box.style, {
          position: "absolute",
          left: `${bounds.left}px`,
          top: `${bounds.top}px`,
          width: `${Math.max(bounds.width, 2)}px`,
          height: `${bounds.height}px`,
          background: color,
          opacity: "0.22",
        });
        this.layer.append(box);
      }
      at += part;
      left -= part;
      if (left <= 0) break;
    }
  }

  destroy() {
    this.resize.disconnect();
    for (const timer of this.labelTimers.values()) window.clearTimeout(timer);
    this.layer.remove();
  }
}

/**
 * Joins the Quill editor to a session: what's typed goes up, what others type
 * comes in, and their carets show. Waits for the editor, and for a long
 * note's text, which is put in after it opens.
 */
export function useCollabEditor(
  session: CollabSession | null | undefined,
  getQuill: () => unknown,
  isReady: boolean,
  onRemoteChange: () => void,
) {
  useEffect(() => {
    if (!session || !isReady) return;
    let waiting: number | undefined;
    let cleanup: (() => void) | undefined;
    const start = () => {
      const quill = getQuill() as QuillLike | null;
      if (!quill) {
        // A timer, not a frame: a page opened in a background tab joins too.
        waiting = window.setTimeout(start, 50);
        return;
      }
      const layer = new CursorLayer(quill);
      const stopPeers = session.listenToPeers((peers) => layer.setPeers(peers));
      let isApplying = false;
      const onText = (change: { ops: Op[] }) => {
        if (!isApplying) session.localChange(new Delta(change.ops));
        layer.draw();
      };
      const onSelection = (range: { index: number; length: number } | null) =>
        session.setCursor(
          range && { index: range.index, length: range.length },
        );
      quill.on("text-change", onText as never);
      quill.on("selection-change", onSelection as never);
      session.attachEditor({
        getDoc: () => new Delta(quill.getContents().ops as Op[]),
        apply: (change) => {
          isApplying = true;
          try {
            quill.updateContents(change as never, "api");
          } finally {
            isApplying = false;
          }
          onRemoteChange();
        },
      });
      const here = quill.getSelection();
      if (here) session.setCursor({ index: here.index, length: here.length });
      cleanup = () => {
        session.detachEditor();
        quill.off("text-change", onText as never);
        quill.off("selection-change", onSelection as never);
        stopPeers();
        layer.destroy();
      };
    };
    start();
    return () => {
      window.clearTimeout(waiting);
      cleanup?.();
    };
  }, [session, isReady, getQuill, onRemoteChange]);
}
