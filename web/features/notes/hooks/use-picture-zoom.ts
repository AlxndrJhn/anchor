"use client";

import * as React from "react";

const MIN_ZOOM = 0.1;
const MAX_ZOOM = 10;
const STEP = 1.25;

type Size = { w: number; h: number };
type Point = { x: number; y: number };

const clampZoom = (z: number) => Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, z));

/**
 * Zoom and pan for the picture viewer. The picture starts fitted to the
 * stage (zoom 1); zoom is relative to that fit, so it can go below it too.
 * Resets whenever `key` changes.
 */
export function usePictureZoom(key: string) {
  const [el, stageRef] = React.useState<HTMLDivElement | null>(null);
  const [stage, setStage] = React.useState<Size | null>(null);
  const [natural, setNatural] = React.useState<Size | null>(null);
  const [zoom, setZoom] = React.useState(1);
  const [offset, setOffset] = React.useState<Point>({ x: 0, y: 0 });
  const [dragging, setDragging] = React.useState(false);
  const drag = React.useRef<{ start: Point; from: Point } | null>(null);

  const [lastKey, setLastKey] = React.useState(key);
  if (key !== lastKey) {
    setLastKey(key);
    setNatural(null);
    setZoom(1);
    setOffset({ x: 0, y: 0 });
  }

  React.useEffect(() => {
    if (!el) return;
    const observer = new ResizeObserver(() =>
      setStage({ w: el.clientWidth, h: el.clientHeight }),
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [el]);

  const fit =
    stage && natural?.w && natural.h
      ? Math.min(stage.w / natural.w, stage.h / natural.h)
      : null;
  const base = React.useMemo(
    () => (fit && natural ? { w: natural.w * fit, h: natural.h * fit } : null),
    [fit, natural],
  );

  // Keeps the picture from being dragged off the stage.
  const clampOffset = React.useCallback(
    (o: Point, z: number): Point => {
      if (!stage || !base) return { x: 0, y: 0 };
      const maxX = Math.max(0, (base.w * z - stage.w) / 2);
      const maxY = Math.max(0, (base.h * z - stage.h) / 2);
      return {
        x: Math.min(maxX, Math.max(-maxX, o.x)),
        y: Math.min(maxY, Math.max(-maxY, o.y)),
      };
    },
    [stage, base],
  );

  /** Zooms by `factor`, keeping `at` (relative to the stage centre) still. */
  const zoomBy = React.useCallback(
    (factor: number, at: Point = { x: 0, y: 0 }) => {
      if (!base) return;
      const next = clampZoom(zoom * factor);
      const k = next / zoom;
      setZoom(next);
      setOffset((o) =>
        clampOffset(
          { x: at.x - (at.x - o.x) * k, y: at.y - (at.y - o.y) * k },
          next,
        ),
      );
    },
    [base, zoom, clampOffset],
  );

  const reset = React.useCallback(() => {
    setZoom(1);
    setOffset({ x: 0, y: 0 });
  }, []);

  // Wheel needs a non-passive listener to keep the page from scrolling.
  React.useEffect(() => {
    if (!el) return;
    const onWheel = (e: WheelEvent) => {
      if (!base) return;
      e.preventDefault();
      const unit = e.deltaMode === 1 ? 40 : e.deltaMode === 2 ? 800 : 1;
      const rect = el.getBoundingClientRect();
      zoomBy(Math.exp(-e.deltaY * unit * 0.002), {
        x: e.clientX - rect.left - rect.width / 2,
        y: e.clientY - rect.top - rect.height / 2,
      });
    };
    el.addEventListener("wheel", onWheel, { passive: false });
    return () => el.removeEventListener("wheel", onWheel);
  }, [el, base, zoomBy]);

  const pannable =
    !!stage && !!base && (base.w * zoom > stage.w || base.h * zoom > stage.h);

  const onImgRef = React.useCallback((img: HTMLImageElement | null) => {
    if (img?.complete && img.naturalWidth)
      setNatural({ w: img.naturalWidth, h: img.naturalHeight });
  }, []);

  const imgProps = {
    ref: onImgRef,
    draggable: false,
    onLoad: (e: React.SyntheticEvent<HTMLImageElement>) =>
      setNatural({
        w: e.currentTarget.naturalWidth,
        h: e.currentTarget.naturalHeight,
      }),
    style: base
      ? {
          // Centred on the stage, so a zoomed picture can outgrow it evenly.
          position: "absolute" as const,
          left: "50%",
          top: "50%",
          width: base.w,
          height: base.h,
          marginLeft: -base.w / 2,
          marginTop: -base.h / 2,
          maxWidth: "none",
          maxHeight: "none",
          transform: `translate(${offset.x}px, ${offset.y}px) scale(${zoom})`,
          cursor: pannable ? (dragging ? "grabbing" : "grab") : undefined,
        }
      : undefined,
  };

  const panProps = {
    onPointerDown: (e: React.PointerEvent) => {
      if (!pannable || e.pointerType !== "mouse" || e.button !== 0) return;
      drag.current = { start: { x: e.clientX, y: e.clientY }, from: offset };
      e.currentTarget.setPointerCapture(e.pointerId);
      setDragging(true);
    },
    onPointerMove: (e: React.PointerEvent) => {
      const d = drag.current;
      if (!d) return;
      setOffset(
        clampOffset(
          {
            x: d.from.x + e.clientX - d.start.x,
            y: d.from.y + e.clientY - d.start.y,
          },
          zoom,
        ),
      );
    },
    onPointerUp: () => {
      drag.current = null;
      setDragging(false);
    },
    onPointerCancel: () => {
      drag.current = null;
      setDragging(false);
    },
  };

  return {
    stageRef,
    imgProps,
    panProps,
    ready: !!base,
    zoomed: zoom !== 1,
    /** Size against the picture's own pixels, as a percentage. */
    percent: fit ? Math.round(fit * zoom * 100) : null,
    canZoomIn: zoom < MAX_ZOOM,
    canZoomOut: zoom > MIN_ZOOM,
    zoomIn: () => zoomBy(STEP),
    zoomOut: () => zoomBy(1 / STEP),
    reset,
  };
}
