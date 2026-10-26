"use client";

import { ClipboardCopy, TextCursorInput, TextSelect } from "lucide-react";
import * as React from "react";
import { toast } from "@/components/ui/toast";
import { type ImageText, imageWordAt, joinImageWords } from "@/lib/image-text";

/** How long a finger holds still before a drag selects text. */
const HOLD_MS = 400;
/** How far a finger may move and still count as holding still. */
const STILL_PX = 10;

interface Press {
  pointerId: number;
  x: number;
  y: number;
  touch: boolean;
  /** Selecting: the pointer sweeps words; otherwise it may yet be a tap. */
  selecting: boolean;
  moved: boolean;
  timer?: number;
}

/**
 * A picture with the text found in it marked, to pick some of it, as the
 * text actions on Windows do: drag over words (hold first on a touch
 * screen), click one, or select all; then copy it or put it in the note.
 */
export function ImageTextView({
  src,
  alt,
  text,
  onInsert,
}: {
  src: string;
  alt: string;
  text: ImageText;
  /** Puts the chosen text in the note; absent when it can't be edited. */
  onInsert?: (text: string) => void;
}) {
  const { words } = text;
  const [selection, setSelectionState] = React.useState<{
    anchor: number;
    focus: number;
  } | null>(null);
  // Said in the status line: a toast would cover these buttons.
  const [copied, setCopied] = React.useState(false);
  // A new selection hasn't been copied.
  const setSelection: typeof setSelectionState = (next) => {
    setCopied(false);
    setSelectionState(next);
  };
  const picture = React.useRef<HTMLDivElement>(null);
  const root = React.useRef<HTMLDivElement>(null);
  const press = React.useRef<Press | null>(null);
  const copiedTimer = React.useRef<number | undefined>(undefined);

  React.useEffect(() => root.current?.focus(), []);
  React.useEffect(
    () => () => {
      window.clearTimeout(press.current?.timer);
      window.clearTimeout(copiedTimer.current);
    },
    [],
  );

  const first = selection ? Math.min(selection.anchor, selection.focus) : -1;
  const last = selection ? Math.max(selection.anchor, selection.focus) : -2;
  const chosen = last - first + 1;
  const chosenText = () => joinImageWords(words.slice(first, last + 1));

  /** The word under a pointer, with a finger's width of slack. */
  const wordAt = (clientX: number, clientY: number) => {
    const box = picture.current?.getBoundingClientRect();
    if (!box?.width) return null;
    const scale = text.width / box.width;
    return imageWordAt(
      words,
      (clientX - box.left) * scale,
      (clientY - box.top) * scale,
      12 * scale,
    );
  };

  const startSelecting = (at: number | null) => {
    if (at === null || !press.current) return;
    press.current.selecting = true;
    setSelection({ anchor: at, focus: at });
  };

  const selectAll = () =>
    words.length && setSelection({ anchor: 0, focus: words.length - 1 });

  const copy = async () => {
    if (chosen <= 0) return;
    try {
      await navigator.clipboard.writeText(chosenText());
      setCopied(true);
      window.clearTimeout(copiedTimer.current);
      copiedTimer.current = window.setTimeout(() => setCopied(false), 2000);
    } catch {
      toast.error("Couldn’t copy the text");
    }
  };

  return (
    <div
      ref={root}
      className="itv"
      tabIndex={-1}
      onKeyDown={(e) => {
        if (!(e.ctrlKey || e.metaKey)) return;
        const key = e.key.toLowerCase();
        if (key === "a") {
          e.preventDefault();
          selectAll();
        } else if (key === "c" && chosen > 0) {
          e.preventDefault();
          void copy();
        }
      }}
    >
      <div className="itv-stage">
        <div
          ref={picture}
          className="itv-pic"
          style={
            {
              "--w": text.width,
              "--h": text.height,
            } as React.CSSProperties
          }
          onPointerDown={(e) => {
            if (e.button !== 0) return;
            e.currentTarget.setPointerCapture(e.pointerId);
            const at = wordAt(e.clientX, e.clientY);
            const touch = e.pointerType !== "mouse";
            press.current = {
              pointerId: e.pointerId,
              x: e.clientX,
              y: e.clientY,
              touch,
              selecting: false,
              moved: false,
            };
            // A mouse selects as it drags; a finger holds first.
            if (!touch) startSelecting(at);
            else
              press.current.timer = window.setTimeout(() => {
                startSelecting(at);
                navigator.vibrate?.(10);
              }, HOLD_MS);
          }}
          onPointerMove={(e) => {
            const p = press.current;
            if (p?.pointerId !== e.pointerId) return;
            if (Math.hypot(e.clientX - p.x, e.clientY - p.y) > STILL_PX) {
              p.moved = true;
              if (!p.selecting) window.clearTimeout(p.timer);
            }
            if (!p.selecting) return;
            const at = wordAt(e.clientX, e.clientY);
            if (at !== null) setSelection((s) => (s ? { ...s, focus: at } : s));
          }}
          onPointerUp={(e) => {
            const p = press.current;
            if (p?.pointerId !== e.pointerId) return;
            window.clearTimeout(p.timer);
            press.current = null;
            if (p.selecting || p.moved) return;
            // A click or tap: that word, or nothing when beside the text.
            const at = wordAt(e.clientX, e.clientY);
            setSelection(at === null ? null : { anchor: at, focus: at });
          }}
          onPointerCancel={() => {
            window.clearTimeout(press.current?.timer);
            press.current = null;
          }}
        >
          <img src={src} alt={alt} draggable={false} />
          {words.map((word, i) => (
            <span
              key={i}
              aria-hidden
              className="itv-w"
              data-on={i >= first && i <= last ? "" : undefined}
              style={{
                left: `${(word.left / text.width) * 100}%`,
                top: `${(word.top / text.height) * 100}%`,
                width: `${((word.right - word.left) / text.width) * 100}%`,
                height: `${((word.bottom - word.top) / text.height) * 100}%`,
              }}
            />
          ))}
        </div>
      </div>
      <div className="itv-bar">
        <div className="itv-status" aria-live="polite">
          {copied ? (
            "Copied"
          ) : chosen > 0 ? (
            `${chosen} ${chosen === 1 ? "word" : "words"} selected`
          ) : (
            <>
              <span className="dk">Drag over the text to select it</span>
              <span className="ph">Hold a word and drag to select text</span>
            </>
          )}
        </div>
        <div className="itv-actions">
          <button
            type="button"
            onClick={selectAll}
            disabled={chosen === words.length}
          >
            <TextSelect aria-hidden />
            Select all
          </button>
          <button type="button" onClick={copy} disabled={chosen <= 0}>
            <ClipboardCopy aria-hidden />
            Copy
          </button>
          {onInsert && (
            <button
              type="button"
              className="itv-insert"
              onClick={() => onInsert(chosenText())}
              disabled={chosen <= 0}
            >
              <TextCursorInput aria-hidden />
              Insert in note
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
