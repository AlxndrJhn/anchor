// Hand-drawn pictures for the text: strokes kept as data, so undo and redo
// are just a list, and drawn at any size (the pad's, or the saved file's).

export type DrawTool = "pen" | "marker" | "eraser";

/** A point as shares of the pad's width (x and y), so the pad can resize. */
export interface DrawPoint {
  x: number;
  y: number;
  /** 0 to 1; 0.5 for a mouse or finger. */
  pressure: number;
}

export interface Stroke {
  tool: DrawTool;
  color: string;
  /** As a share of the pad's width. */
  size: number;
  points: DrawPoint[];
}

export const DRAW_COLORS = [
  { name: "Black", value: "#1f1f1f" },
  { name: "Red", value: "#d93025" },
  { name: "Orange", value: "#f29900" },
  { name: "Green", value: "#188038" },
  { name: "Blue", value: "#1a73e8" },
  { name: "Purple", value: "#9334e6" },
] as const;

/** Pen widths, as shares of the pad's width. */
export const DRAW_SIZES = [
  { name: "Thin", value: 0.004 },
  { name: "Medium", value: 0.009 },
  { name: "Thick", value: 0.02 },
] as const;

/** The pad's height, as a share of its width. */
export const DRAW_ASPECT = 3 / 4;

/** How wide a blank drawing is saved, in pixels. */
export const DRAW_EXPORT_WIDTH = 1600;

/** A marker is this much wider than a pen, and see-through. */
const MARKER_SCALE = 3;
const MARKER_ALPHA = 0.35;
const ERASER_SCALE = 2.5;

/** The stroke's width at a point, in shares of the pad's width. */
export function strokeWidth(stroke: Stroke, pressure: number) {
  const scale =
    stroke.tool === "marker"
      ? MARKER_SCALE
      : stroke.tool === "eraser"
        ? ERASER_SCALE
        : 0.5 + pressure;
  return stroke.size * scale;
}

/**
 * Draws strokes onto `context`, `width` pixels wide. A marker stroke is
 * drawn whole and then made see-through, so it doesn't darken where it
 * crosses itself; an eraser clears ink only, as the ink has its own layer.
 */
export function drawStrokes(
  context: CanvasRenderingContext2D,
  strokes: readonly Stroke[],
  width: number,
) {
  for (const stroke of strokes) drawStroke(context, stroke, width);
}

export function drawStroke(
  context: CanvasRenderingContext2D,
  stroke: Stroke,
  width: number,
) {
  const points = stroke.points;
  if (!points.length) return;
  context.save();
  context.lineCap = "round";
  context.lineJoin = "round";
  context.globalCompositeOperation =
    stroke.tool === "eraser" ? "destination-out" : "source-over";
  context.globalAlpha = stroke.tool === "marker" ? MARKER_ALPHA : 1;
  context.strokeStyle = stroke.color;
  context.fillStyle = stroke.color;
  const at = (p: DrawPoint) => [p.x * width, p.y * width] as const;

  if (points.length === 1) {
    const [x, y] = at(points[0]);
    context.beginPath();
    context.arc(
      x,
      y,
      (strokeWidth(stroke, points[0].pressure) * width) / 2,
      0,
      Math.PI * 2,
    );
    context.fill();
    context.restore();
    return;
  }

  const varies =
    stroke.tool === "pen" && points.some((p) => p.pressure !== 0.5);
  if (!varies) {
    // One path, smoothed through the midpoints between points.
    context.lineWidth = strokeWidth(stroke, 0.5) * width;
    context.beginPath();
    const [x0, y0] = at(points[0]);
    context.moveTo(x0, y0);
    for (let i = 1; i < points.length - 1; i++) {
      const [x, y] = at(points[i]);
      const [nx, ny] = at(points[i + 1]);
      context.quadraticCurveTo(x, y, (x + nx) / 2, (y + ny) / 2);
    }
    const [xl, yl] = at(points[points.length - 1]);
    context.lineTo(xl, yl);
    context.stroke();
  } else {
    // A stylus: each piece as wide as the pressure there.
    for (let i = 1; i < points.length; i++) {
      const [px, py] = at(points[i - 1]);
      const [x, y] = at(points[i]);
      context.lineWidth =
        strokeWidth(stroke, (points[i - 1].pressure + points[i].pressure) / 2) *
        width;
      context.beginPath();
      context.moveTo(px, py);
      context.lineTo(x, y);
      context.stroke();
    }
  }
  context.restore();
}

/** Whether the strokes leave any ink, i.e. aren't all erasing. */
export function hasInk(strokes: readonly Stroke[]) {
  return strokes.some((s) => s.tool !== "eraser" && s.points.length > 0);
}

/** Drops a point too close to the last to change the line, in shares. */
export function addPoint(points: DrawPoint[], point: DrawPoint, min = 0.0015) {
  const last = points[points.length - 1];
  if (last && Math.hypot(point.x - last.x, point.y - last.y) < min)
    return false;
  points.push(point);
  return true;
}

/**
 * The finished picture: white paper, or `background` at its own size, with
 * the ink over it. Always a PNG, so lines stay sharp.
 */
export async function renderDrawing(
  strokes: readonly Stroke[],
  background?: Blob | null,
): Promise<File> {
  const bitmap = background ? await createImageBitmap(background) : null;
  try {
    const width = bitmap?.width ?? DRAW_EXPORT_WIDTH;
    const height = bitmap?.height ?? Math.round(width * DRAW_ASPECT);
    const ink = document.createElement("canvas");
    ink.width = width;
    ink.height = height;
    const inkContext = ink.getContext("2d");
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    if (!context || !inkContext) throw new Error("No canvas");
    drawStrokes(inkContext, strokes, width);
    if (bitmap) context.drawImage(bitmap, 0, 0);
    else {
      context.fillStyle = "#ffffff";
      context.fillRect(0, 0, width, height);
    }
    context.drawImage(ink, 0, 0);
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, "image/png"),
    );
    if (!blob) throw new Error("Couldn’t encode the drawing");
    return new File([blob], drawingName(), { type: "image/png" });
  } finally {
    bitmap?.close();
  }
}

/** “Drawing 2026-11-14-09-30-12-345.png”, named as pictures are. */
export function drawingName(at = new Date()) {
  const pad = (n: number, size = 2) => String(n).padStart(size, "0");
  const stamp = [
    at.getFullYear(),
    pad(at.getMonth() + 1),
    pad(at.getDate()),
    pad(at.getHours()),
    pad(at.getMinutes()),
    pad(at.getSeconds()),
    pad(at.getMilliseconds(), 3),
  ].join("-");
  return `Drawing ${stamp}.png`;
}
