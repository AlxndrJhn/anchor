import { prefersReducedMotion } from "./motion";

/** How long a card takes to burn away, in ms. */
export const DESTROY_MS = 1100;

/** The jolt takes the start of the effect; the burn the rest. */
const JOLT_END = 0.14;
/** How far the glowing edge reaches into the card, in thresholds. */
const EDGE = 0.1;
/** Room around the card for the sparks, in px. */
const MARGIN = 40;
const GLOW = ["#FFF6C8", "#FFC94A", "#FF7A2E", "#E2362B"];

export interface BurnPattern {
  columns: number;
  rows: number;
  cell: number;
  /** One per block, row by row: when it burns, from 0 (first) to 1 (last). */
  thresholds: number[];
}

/** A small seeded random, so a card always burns the same way. */
function seeded(seed: number) {
  let s = seed >>> 0 || 1;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

/** Where a card burns first: smooth patches, like Balatro's dissolve. */
export function burnPattern(
  width: number,
  height: number,
  seed = 0,
): BurnPattern {
  // Small cards in fine pixels; a whole page in coarser ones.
  const cell = Math.min(14, Math.max(5, Math.sqrt((width * height) / 1800)));
  const columns = Math.max(1, Math.ceil(width / cell));
  const rows = Math.max(1, Math.ceil(height / cell));
  const random = seeded(seed);
  // Patches about a quarter of the card across, so it burns in holes that
  // spread rather than in specks.
  const blob = Math.min(90, Math.max(24, Math.min(width, height) / 4)) / cell;
  const lw = Math.ceil(columns / blob) + 2;
  const lattice = Array.from(
    { length: lw * (Math.ceil(rows / blob) + 2) },
    random,
  );
  const at = (x: number, y: number) => lattice[y * lw + x];
  const smooth = (t: number) => t * t * (3 - 2 * t);
  const raw: number[] = [];
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < columns; x++) {
      const fx = x / blob;
      const fy = y / blob;
      const ix = Math.floor(fx);
      const iy = Math.floor(fy);
      const tx = smooth(fx - ix);
      const ty = smooth(fy - iy);
      const top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * tx;
      const bottom =
        at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * tx;
      raw.push(top + (bottom - top) * ty + random() * 0.08);
    }
  }
  const low = Math.min(...raw);
  const span = Math.max(...raw) - low || 1;
  return { columns, rows, cell, thresholds: raw.map((v) => (v - low) / span) };
}

/** How far the burn has gone at t (0 to 1 of the effect), to just past 1. */
export function burnFront(t: number): number {
  if (t <= JOLT_END) return 0;
  const d = (t - JOLT_END) / (1 - JOLT_END);
  return d * d * (1 + EDGE * 1.2);
}

export type BlockState = "whole" | "burning" | "gone";

export function blockState(threshold: number, front: number): BlockState {
  if (threshold < front - EDGE) return "gone";
  if (threshold < front) return "burning";
  return "whole";
}

/**
 * The whole blocks as a clip path, a rectangle per run of them in a row, in
 * the card's own pixels.
 */
export function wholeBlocksPath(
  pattern: BurnPattern,
  front: number,
  width: number,
  height: number,
): string {
  const { columns, rows, cell, thresholds } = pattern;
  let path = "";
  for (let y = 0; y < rows; y++) {
    const top = y * cell;
    const bottom = Math.min(height, top + cell);
    let start = -1;
    for (let x = 0; x <= columns; x++) {
      const whole =
        x < columns &&
        blockState(thresholds[y * columns + x], front) === "whole";
      if (whole && start < 0) start = x;
      if (!whole && start >= 0) {
        const left = start * cell;
        const right = Math.min(width, x * cell);
        path += `M${left} ${top}H${right}V${bottom}H${left}Z`;
        start = -1;
      }
    }
  }
  // An empty path would show the whole card.
  return path || "M0 0Z";
}

/** A copy of [el] where it stands, typed-in values and all. */
function copyOf(el: HTMLElement, rect: DOMRect, inBox: boolean) {
  const copy = el.cloneNode(true) as HTMLElement;
  copy.removeAttribute("data-flip");
  for (const node of [copy, ...copy.querySelectorAll("[id]")])
    node.removeAttribute("id");
  const fields = el.querySelectorAll("input, textarea");
  copy.querySelectorAll("input, textarea").forEach((field, i) => {
    (field as HTMLInputElement).value = (fields[i] as HTMLInputElement).value;
  });
  Object.assign(copy.style, {
    position: "relative",
    left: "0",
    top: "0",
    width: "100%",
    height: "100%",
    margin: "0",
  });
  // A card sits in a box like the list's, so it keeps the card's layout.
  const box = document.createElement("div");
  if (inBox && el.parentElement) box.className = el.parentElement.className;
  box.setAttribute("aria-hidden", "true");
  Object.assign(box.style, {
    position: "fixed",
    left: `${rect.left}px`,
    top: `${rect.top}px`,
    width: `${rect.width}px`,
    height: `${rect.height}px`,
    margin: "0",
    padding: "0",
    zIndex: "var(--z-float, 50)",
    pointerEvents: "none",
  });
  box.append(copy);
  return box;
}

/**
 * Burns [el] away where it stands, as Balatro destroys a card: a jolt, then
 * it dissolves in glowing pixels and sparks. [el] is hidden at once and a
 * copy burns in its place, so the list can let it go whenever it likes.
 * Returns a function that brings [el] back, for when the delete fails.
 */
export function destroyElement(
  el: HTMLElement,
  { inBox = false }: { inBox?: boolean } = {},
): () => void {
  const hidden = el.style.visibility;
  const unhide = () => {
    el.style.visibility = hidden;
  };
  if (prefersReducedMotion()) return unhide;
  const rect = el.getBoundingClientRect();
  if (rect.width === 0 || rect.height === 0) return unhide;

  const box = copyOf(el, rect, inBox);
  const canvas = document.createElement("canvas");
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  const area = { w: rect.width + MARGIN * 2, h: rect.height + MARGIN * 2 };
  canvas.width = Math.ceil(area.w * ratio);
  canvas.height = Math.ceil(area.h * ratio);
  canvas.setAttribute("aria-hidden", "true");
  Object.assign(canvas.style, {
    position: "fixed",
    left: `${rect.left - MARGIN}px`,
    top: `${rect.top - MARGIN}px`,
    width: `${area.w}px`,
    height: `${area.h}px`,
    zIndex: "var(--z-float, 50)",
    pointerEvents: "none",
  });
  document.body.append(box, canvas);
  el.style.visibility = "hidden";

  const copy = box.firstElementChild as HTMLElement;
  const pattern = burnPattern(
    rect.width,
    rect.height,
    Math.round(rect.left * 31 + rect.top * 17),
  );
  const context = canvas.getContext("2d");
  const start = performance.now();
  const frame = (now: number) => {
    const t = Math.min(1, (now - start) / DESTROY_MS);
    const front = burnFront(t);
    // The jolt: a shake that settles, a little bigger, a flash.
    const jolt = Math.max(0, 1 - t / JOLT_END);
    const grow = 1 + 0.06 * Math.sin(Math.min(1, t / JOLT_END) * Math.PI);
    box.style.transform = `translateX(${Math.sin(t * 130) * 4 * jolt}px) rotate(${Math.sin(t * 90) * 0.05 * jolt}rad) scale(${grow})`;
    copy.style.filter = jolt > 0 ? `brightness(${1 + 0.6 * jolt})` : "";
    copy.style.clipPath = `path("${wholeBlocksPath(pattern, front, rect.width, rect.height)}")`;
    if (context) drawBurn(context, pattern, front, rect, ratio);
    if (t < 1) requestAnimationFrame(frame);
    else {
      box.remove();
      canvas.remove();
    }
  };
  requestAnimationFrame(frame);
  return unhide;
}

/** The glowing edge and the sparks, around the card's whole blocks. */
function drawBurn(
  context: CanvasRenderingContext2D,
  pattern: BurnPattern,
  front: number,
  rect: DOMRect,
  ratio: number,
) {
  const { columns, rows, cell, thresholds } = pattern;
  context.setTransform(ratio, 0, 0, ratio, 0, 0);
  context.clearRect(0, 0, rect.width + MARGIN * 2, rect.height + MARGIN * 2);
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < columns; x++) {
      const threshold = thresholds[y * columns + x];
      const left = MARGIN + x * cell;
      const top = MARGIN + y * cell;
      const w = Math.min(cell, MARGIN + rect.width - left);
      const h = Math.min(cell, MARGIN + rect.height - top);
      const state = blockState(threshold, front);
      if (state === "burning") {
        // Hottest at the very edge, cooling into the card.
        const heat = Math.min(0.999, (front - threshold) / EDGE);
        context.fillStyle = GLOW[Math.floor(heat * GLOW.length)];
        context.fillRect(left, top, w, h);
      } else if (state === "gone" && (x * 7 + y * 13) % 5 === 0) {
        // Some burnt blocks fly off as sparks, up and away.
        const age = (front - EDGE - threshold) * 2.2;
        if (age > 1) continue;
        const drift = Math.sin(x * 12.9898 + y * 78.233) * 22;
        const size = cell * 0.6 * (1 - age);
        context.globalAlpha = 0.9;
        context.fillStyle =
          GLOW[Math.min(GLOW.length - 1, Math.floor(age * GLOW.length))];
        context.fillRect(
          left + w / 2 + drift * age - size / 2,
          top + h / 2 - 46 * age - size / 2,
          size,
          size,
        );
        context.globalAlpha = 1;
      }
    }
  }
}

/**
 * Burns away the cards of notes [ids] on screen. Returns a function that
 * brings them back, for when the delete fails.
 */
export function destroyNoteCards(ids: readonly string[]): () => void {
  const restores = ids.flatMap((id) => {
    const card = document.querySelector<HTMLElement>(
      `article.nc[data-flip="${CSS.escape(id)}"]`,
    );
    return card ? [destroyElement(card, { inBox: true })] : [];
  });
  return () => {
    for (const restore of restores) restore();
  };
}

/**
 * Burns away the open note [id]'s page. Returns a function that brings it
 * back, for when the delete fails.
 */
export function destroyNotePage(id: string): () => void {
  const page = document.querySelector<HTMLElement>(
    `[data-note-page="${CSS.escape(id)}"]`,
  );
  return page ? destroyElement(page) : () => {};
}
