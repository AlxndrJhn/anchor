"use client";

import { Eraser, Highlighter, Pen, Redo2, Trash2, Undo2 } from "lucide-react";
import * as React from "react";
import { Button, IconButton } from "@/components/ui/button";
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { toast } from "@/components/ui/toast";
import { Tip } from "@/components/ui/tooltip";
import { isMac } from "@/lib/platform";
import { cn } from "@/lib/utils";
import {
  addPoint,
  DRAW_ASPECT,
  DRAW_COLORS,
  DRAW_SIZES,
  type DrawPoint,
  type DrawTool,
  drawStroke,
  drawStrokes,
  hasInk,
  renderDrawing,
  type Stroke,
} from "../../drawing";

const TOOLS: { tool: DrawTool; label: string; icon: React.ReactNode }[] = [
  { tool: "pen", label: "Pen", icon: <Pen /> },
  { tool: "marker", label: "Marker", icon: <Highlighter /> },
  { tool: "eraser", label: "Eraser", icon: <Eraser /> },
];

/**
 * A pad to draw on with a mouse, finger or stylus (its pressure changes the
 * pen's width). With `background`, draws on that picture; the eraser only
 * takes away ink. Saving makes a PNG.
 */
export function DrawingDialog({
  open,
  background = null,
  onClose,
  onSave,
}: {
  open: boolean;
  /** A picture to draw on; blank paper without one. */
  background?: Blob | null;
  onClose: () => void;
  onSave: (file: File) => void;
}) {
  const [strokes, setStrokes] = React.useState<Stroke[]>([]);
  const [undone, setUndone] = React.useState<Stroke[]>([]);
  const [tool, setTool] = React.useState<DrawTool>("pen");
  const [color, setColor] = React.useState<string>(DRAW_COLORS[0].value);
  const [size, setSize] = React.useState<number>(DRAW_SIZES[1].value);
  const [saving, setSaving] = React.useState(false);
  const [backgroundUrl, setBackgroundUrl] = React.useState<string | null>(null);
  const [aspect, setAspect] = React.useState(DRAW_ASPECT);
  const [pad, setPad] = React.useState<HTMLDivElement | null>(null);
  const canvas = React.useRef<HTMLCanvasElement>(null);
  const live = React.useRef<Stroke | null>(null);
  const strokesRef = React.useRef(strokes);
  strokesRef.current = strokes;

  // Starts over each time it opens.
  React.useEffect(() => {
    if (!open) return;
    setStrokes([]);
    setUndone([]);
    setTool("pen");
    setSaving(false);
    live.current = null;
  }, [open]);

  React.useEffect(() => {
    if (!open || !background) {
      setBackgroundUrl(null);
      setAspect(DRAW_ASPECT);
      return;
    }
    const url = URL.createObjectURL(background);
    setBackgroundUrl(url);
    let cancelled = false;
    void createImageBitmap(background).then(
      (bitmap) => {
        if (!cancelled && bitmap.width) setAspect(bitmap.height / bitmap.width);
        bitmap.close();
      },
      () => undefined,
    );
    return () => {
      cancelled = true;
      URL.revokeObjectURL(url);
    };
  }, [open, background]);

  /** Draws every stroke again, at the canvas's size. */
  const redraw = React.useCallback(() => {
    const el = canvas.current;
    const context = el?.getContext("2d");
    if (!el || !context) return;
    context.clearRect(0, 0, el.width, el.height);
    drawStrokes(context, strokesRef.current, el.width);
    if (live.current) drawStroke(context, live.current, el.width);
  }, []);

  // The canvas has as many pixels as the screen shows, at any size.
  React.useEffect(() => {
    const el = canvas.current;
    if (!pad || !el) return;
    const fitToPad = () => {
      const ratio = window.devicePixelRatio || 1;
      const width = Math.round(pad.clientWidth * ratio);
      const height = Math.round(pad.clientHeight * ratio);
      if (el.width === width && el.height === height) return;
      el.width = width;
      el.height = height;
      redraw();
    };
    fitToPad();
    const observer = new ResizeObserver(fitToPad);
    observer.observe(pad);
    return () => observer.disconnect();
  }, [pad, redraw]);

  // biome-ignore lint/correctness/useExhaustiveDependencies: strokes change what is drawn
  React.useEffect(redraw, [strokes, redraw]);

  const pointAt = (e: PointerEvent | React.PointerEvent): DrawPoint | null => {
    if (!pad) return null;
    const box = pad.getBoundingClientRect();
    if (!box.width) return null;
    return {
      x: (e.clientX - box.left) / box.width,
      y: (e.clientY - box.top) / box.width,
      pressure: e.pointerType === "pen" && e.pressure > 0 ? e.pressure : 0.5,
    };
  };

  const start = (e: React.PointerEvent<HTMLDivElement>) => {
    if (e.button !== 0 || live.current) return;
    const point = pointAt(e);
    if (!point) return;
    e.preventDefault();
    const target = e.currentTarget;
    try {
      target.setPointerCapture(e.pointerId);
    } catch {
      // Not a pointer the browser knows.
    }
    const pointerId = e.pointerId;
    const stroke: Stroke = { tool, color, size, points: [point] };
    live.current = stroke;
    redraw();
    const move = (event: PointerEvent) => {
      if (event.pointerId !== pointerId) return;
      // Coalesced events keep fast lines smooth.
      const events = event.getCoalescedEvents?.() ?? [event];
      let changed = false;
      for (const each of events.length ? events : [event]) {
        const next = pointAt(each);
        if (next && addPoint(stroke.points, next)) changed = true;
      }
      if (changed) redraw();
    };
    const end = (event: PointerEvent) => {
      if (event.pointerId !== pointerId) return;
      target.removeEventListener("pointermove", move);
      target.removeEventListener("pointerup", end);
      target.removeEventListener("pointercancel", end);
      live.current = null;
      setStrokes((current) => [...current, stroke]);
      setUndone([]);
    };
    target.addEventListener("pointermove", move);
    target.addEventListener("pointerup", end);
    target.addEventListener("pointercancel", end);
  };

  const undo = () => {
    const last = strokes[strokes.length - 1];
    if (!last) return;
    setStrokes(strokes.slice(0, -1));
    setUndone([...undone, last]);
  };
  const redo = () => {
    const last = undone[undone.length - 1];
    if (!last) return;
    setUndone(undone.slice(0, -1));
    setStrokes([...strokes, last]);
  };
  const clear = () => {
    if (!strokes.length) return;
    // Clearing is one step back, so it can be undone too.
    setUndone([]);
    setStrokes([]);
    const cleared = strokes;
    toast.success("Drawing cleared", {
      undo: () => setStrokes(cleared),
    });
  };

  const save = async () => {
    setSaving(true);
    try {
      onSave(await renderDrawing(strokes, background));
    } catch {
      toast.error("Couldn’t save the drawing");
      setSaving(false);
    }
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    const mod = isMac() ? e.metaKey : e.ctrlKey;
    if (!mod || e.altKey) return;
    const key = e.key.toLowerCase();
    if (key === "z" && !e.shiftKey) {
      e.preventDefault();
      undo();
    } else if ((key === "z" && e.shiftKey) || key === "y") {
      e.preventDefault();
      redo();
    }
  };

  const modKey = isMac() ? "⌘" : "Ctrl+";
  const canSave = hasInk(strokes);
  const showsColor = tool !== "eraser";

  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent
        size="lg"
        onKeyDown={onKeyDown}
        // A stray click beside the pad mustn't throw the drawing away.
        onInteractOutside={(e) => {
          if (strokesRef.current.length) e.preventDefault();
        }}
      >
        <DialogHeader>
          <DialogTitle>
            {background ? "Draw on picture" : "Draw a picture"}
          </DialogTitle>
        </DialogHeader>
        <DialogBody className="gap-3">
          <div
            role="toolbar"
            aria-label="Drawing tools"
            className="flex flex-wrap items-center gap-x-3 gap-y-2"
          >
            <div className="flex items-center gap-0.5">
              {TOOLS.map((each) => (
                <Tip key={each.tool} label={each.label}>
                  <IconButton
                    size="sm"
                    label={each.label}
                    aria-pressed={tool === each.tool}
                    onClick={() => setTool(each.tool)}
                  >
                    {each.icon}
                  </IconButton>
                </Tip>
              ))}
            </div>
            <div
              className={cn(
                "flex items-center gap-1",
                !showsColor && "pointer-events-none opacity-35",
              )}
            >
              {DRAW_COLORS.map((each) => (
                <button
                  key={each.value}
                  type="button"
                  aria-pressed={color === each.value}
                  aria-label={each.name}
                  title={each.name}
                  tabIndex={showsColor ? undefined : -1}
                  onClick={() => setColor(each.value)}
                  className={cn(
                    "size-6 cursor-pointer rounded-full border-0 p-0 shadow-[inset_0_0_0_1px_rgb(0_0_0/.15)] transition-shadow",
                    color === each.value &&
                      "shadow-[0_0_0_2px_var(--card),0_0_0_4px_var(--foreground)]",
                  )}
                  style={{ backgroundColor: each.value }}
                />
              ))}
            </div>
            <div className="flex items-center gap-0.5">
              {DRAW_SIZES.map((each) => (
                <Tip key={each.name} label={each.name}>
                  <IconButton
                    size="sm"
                    label={each.name}
                    aria-pressed={size === each.value}
                    onClick={() => setSize(each.value)}
                  >
                    <span
                      aria-hidden
                      className="block rounded-full bg-current"
                      style={{
                        width: 4 + DRAW_SIZES.indexOf(each) * 4,
                        height: 4 + DRAW_SIZES.indexOf(each) * 4,
                      }}
                    />
                  </IconButton>
                </Tip>
              ))}
            </div>
            <div className="ml-auto flex items-center gap-0.5">
              <Tip label={`Undo (${modKey}Z)`}>
                <IconButton
                  size="sm"
                  label="Undo"
                  disabled={!strokes.length}
                  onClick={undo}
                >
                  <Undo2 />
                </IconButton>
              </Tip>
              <Tip label={`Redo (${isMac() ? "⇧⌘Z" : "Ctrl+Y"})`}>
                <IconButton
                  size="sm"
                  label="Redo"
                  disabled={!undone.length}
                  onClick={redo}
                >
                  <Redo2 />
                </IconButton>
              </Tip>
              <Tip label="Clear">
                <IconButton
                  size="sm"
                  tone="danger"
                  label="Clear"
                  disabled={!strokes.length}
                  onClick={clear}
                >
                  <Trash2 />
                </IconButton>
              </Tip>
            </div>
          </div>
          <div
            ref={setPad}
            role="img"
            aria-label="Drawing pad: draw with the mouse, a finger or a pen"
            data-testid="drawing-pad"
            className={cn(
              "relative w-full touch-none select-none overflow-hidden rounded-md bg-white shadow-[inset_0_0_0_1px_rgb(0_0_0/.12)]",
              tool === "eraser" ? "cursor-cell" : "cursor-crosshair",
            )}
            style={{
              aspectRatio: `1 / ${aspect}`,
              maxHeight: "60vh",
              // Keeps the shape when the height is capped.
              maxWidth: `calc(60vh / ${aspect})`,
              marginInline: "auto",
            }}
            onPointerDown={start}
          >
            {backgroundUrl && (
              <img
                src={backgroundUrl}
                alt=""
                draggable={false}
                className="pointer-events-none absolute inset-0 size-full"
              />
            )}
            <canvas
              ref={canvas}
              className="pointer-events-none absolute inset-0 size-full"
            />
          </div>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button
            type="button"
            disabled={!canSave}
            busy={saving ? "Saving…" : undefined}
            onClick={() => void save()}
          >
            {background ? "Save" : "Insert"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
