/**
 * Text colours, fonts and custom highlight colours, as the notes store
 * them (shared with the Android app): `color` and a custom `highlight` are
 * "#rrggbb"; `font` is one of FONTS' values. The bundled fonts are
 * declared under those names in app/styles/note-fonts.css.
 */

export const TEXT_COLORS = [
  { name: "Red", value: "#e03131" },
  { name: "Orange", value: "#e8590c" },
  { name: "Amber", value: "#f08c00" },
  { name: "Green", value: "#2f9e44" },
  { name: "Teal", value: "#0c8599" },
  { name: "Blue", value: "#1971c2" },
  { name: "Purple", value: "#7048e8" },
  { name: "Pink", value: "#c2255c" },
  { name: "Gray", value: "#868e96" },
] as const;

export const FONTS = [
  { name: "Serif", value: "serif" },
  { name: "Monospace", value: "monospace" },
  { name: "Comic Sans", value: "comic" },
  { name: "Handwriting", value: "handwriting" },
  { name: "Typewriter", value: "typewriter" },
  { name: "Rounded", value: "rounded" },
  { name: "Slab", value: "slab" },
  { name: "Marker", value: "marker" },
] as const;

export type FontName = (typeof FONTS)[number]["value"];

export const isFont = (value: unknown): value is FontName =>
  FONTS.some((font) => font.value === value);

/** A colour as stored: "#rrggbb", lowercase. */
export function isHexColor(value: unknown): value is string {
  return typeof value === "string" && /^#[0-9a-f]{6}$/.test(value);
}

/** "#abc", "#AABBCC", "rgb(1, 2, 3)" → "#aabbcc"; null when not a colour. */
export function toHexColor(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim().toLowerCase();
  if (/^#[0-9a-f]{6}$/.test(text)) return text;
  if (/^#[0-9a-f]{3}$/.test(text))
    return `#${[...text.slice(1)].map((c) => c + c).join("")}`;
  const rgb = /^rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(text);
  if (rgb)
    return `#${rgb
      .slice(1, 4)
      .map((n) => Math.min(255, Number(n)).toString(16).padStart(2, "0"))
      .join("")}`;
  return null;
}

/** Black or white, whichever reads better on [hex]. */
export function inkFor(hex: string): string {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = Number.parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 ? "#1a1a1a" : "#ffffff";
}
