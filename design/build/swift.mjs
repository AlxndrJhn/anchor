// Writes the tokens for the iPhone's native code (the share extension):
// AnchorTokens (the same in light and dark) and AnchorColors, as Dart has them.

const camel = (path) =>
  path
    .split(".")
    .map((p, i) => (i ? p.charAt(0).toUpperCase() + p.slice(1) : p))
    .join("")
    .replace(/-(\w)/g, (_, c) => c.toUpperCase());
const num = (n) => String(+(+n).toFixed(4));

export function swiftTokens({ dtcg, set, resolved, base, HEAD }) {
  const CAT = set.base.$extensions["app.anchor"].catalog;
  const color = (v) => {
    const [r, g, b] = dtcg.rgb(v).map((x) => num(x / 255));
    return `Color(.sRGB, red: ${r}, green: ${g}, blue: ${b}, opacity: ${num(v.alpha ?? 1)})`;
  };
  // Like Flutter, SwiftUI draws the last shadow on top.
  const shadow = (v) =>
    `[${(Array.isArray(v) ? v : [v])
      .filter((s) => !s.inset)
      .reverse()
      .map(
        (s) =>
          `AnchorShadow(color: ${color(s.color)}, x: ${num(s.offsetX.value)}, y: ${num(s.offsetY.value)}, blur: ${num(s.blur.value)}, spread: ${num(s.spread.value)})`,
      )
      .join(", ")}]`;
  const style = (v) =>
    `AnchorTextStyle(size: ${num(v.fontSize.value)}, lineHeight: ${num(v.lineHeight)}, weight: ${dtcg.weight(v.fontWeight)}, tracking: ${num(v.letterSpacing.value)})`;
  const value = (x) =>
    x.type === "color"
      ? color(x.value)
      : x.type === "dimension" || x.type === "number"
        ? num(x.type === "dimension" ? x.value.value : x.value)
        : x.type === "duration"
          ? num(x.value.unit === "s" ? x.value.value : x.value.value / 1000)
          : x.type === "fontWeight"
            ? String(dtcg.weight(x.value))
            : x.type === "typography"
              ? style(x.value)
              : x.type === "shadow"
                ? shadow(x.value)
                : null;
  const type = (x) =>
    ({
      color: "Color",
      dimension: "CGFloat",
      duration: "TimeInterval",
      number: "CGFloat",
      fontWeight: "Int",
      typography: "AnchorTextStyle",
      shadow: "[AnchorShadow]",
    })[x.type];
  const doc = (x) => (x.description ? `    /// ${x.description}\n` : "");

  const constants = [...base.values()]
    .filter(
      (x) =>
        !x.deprecated &&
        !x.path.startsWith("font.family") &&
        !x.path.startsWith("color.tag.") &&
        value(x) !== null,
    )
    .map((x) => `${doc(x)}    static let ${camel(x.path)}: ${type(x)} = ${value(x)}`)
    .join("\n");

  const R = resolved;
  const isThemed = (x) =>
    !x.deprecated &&
    !base.has(x.path) &&
    /^(color\.(app|accent|check|status)\.|shadow\.|blend\.)/.test(x.path);
  const fields = [...R.light.values()]
    .filter(isThemed)
    .map((x) => ({ name: camel(x.path.replace(/^color\./, "")), type: type(x), x }));
  const note = (t, n) => {
    const get = (p) => R[t].get(`color.note.${n}.${p}`).value;
    return `AnchorNoteColors(bg: ${color(get("bg"))}, surface: ${color(get("surface"))}, border: ${color(get("border"))}, pattern: ${color(get("pattern"))}, muted: ${color(get("muted"))})`;
  };
  const theme = (t) => `AnchorColors(
${fields.map((f) => `        ${f.name}: ${value(R[t].get(f.x.path))},`).join("\n")}
        notes: [${CAT.notes.map((n) => `\n            "${n}": ${note(t, n)},`).join("")}
        ],
        tags: [${CAT.tags.map((n) => `\n            "${n}": AnchorTagColors(stored: ${color(R[t].get(`color.tag.${n}.stored`).value)}, hash: ${color(R[t].get(`color.tag.${n}.hash`).value)}, tintFill: ${color(R[t].get(`color.tag.${n}.tintFill`).value)}),`).join("")}
        ]
    )`;
  const hex = (v) =>
    "#" +
    dtcg
      .rgb(v)
      .map((x) => x.toString(16).padStart(2, "0"))
      .join("")
      .toUpperCase();

  return `// ${HEAD}
//
// AnchorTokens holds what stays the same in light and dark, AnchorColors the
// rest. Text styles carry size, weight, line height and tracking only.

import SwiftUI

enum AnchorTokens {
${constants}

    /// Tag palette names by the color a tag stores.
    static let tagNames: [String: String] = [${CAT.tags.map((n) => `\n        "${hex(base.get(`color.tag.${n}.stored`).value)}": "${n}",`).join("")}
    ]

    /// The note palette of a note with no background.
    static let defaultNotePalette = "${CAT.backgrounds.colors[0].note}"
}

struct AnchorTextStyle {
    let size: CGFloat
    /// A multiple of [size].
    let lineHeight: CGFloat
    let weight: Int
    let tracking: CGFloat
}

struct AnchorShadow {
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat
    let spread: CGFloat
}

struct AnchorNoteColors {
    let bg: Color
    let surface: Color
    let border: Color
    let pattern: Color
    let muted: Color
}

/// How a tag is drawn: its stored color, the # on a chip, and its swatch fill.
struct AnchorTagColors {
    let stored: Color
    let hash: Color
    let tintFill: Color
}

struct AnchorColors {
${fields.map((f) => `${f.x.description ? `    /// ${f.x.description}\n` : ""}    let ${f.name}: ${f.type}`).join("\n")}

    /// Note colors by palette name.
    let notes: [String: AnchorNoteColors]

    /// Tag colors by palette name.
    let tags: [String: AnchorTagColors]

    static let light = ${theme("light")}

    static let dark = ${theme("dark")}
}
`;
}

// Lucide icons as SwiftUI paths ----------------------------------------------------

const point = (x, y) => `CGPoint(x: ${num(x)}, y: ${num(y)})`;

// An SVG arc as cubic curves, each at most a quarter turn (SVG spec F.6.5).
function arcCurves(x1, y1, rx, ry, angle, large, sweep, x2, y2) {
  if (x1 === x2 && y1 === y2) return [];
  if (!rx || !ry) return [[x1, y1, x2, y2, x2, y2]];
  const phi = (angle * Math.PI) / 180,
    cos = Math.cos(phi),
    sin = Math.sin(phi);
  const dx = (x1 - x2) / 2,
    dy = (y1 - y2) / 2;
  const xp = cos * dx + sin * dy,
    yp = -sin * dx + cos * dy;
  rx = Math.abs(rx);
  ry = Math.abs(ry);
  const lambda = (xp * xp) / (rx * rx) + (yp * yp) / (ry * ry);
  if (lambda > 1) {
    rx *= Math.sqrt(lambda);
    ry *= Math.sqrt(lambda);
  }
  const sign = large === sweep ? -1 : 1;
  const factor =
    sign *
    Math.sqrt(
      Math.max(
        0,
        (rx * rx * ry * ry - rx * rx * yp * yp - ry * ry * xp * xp) /
          (rx * rx * yp * yp + ry * ry * xp * xp),
      ),
    );
  const cxp = (factor * rx * yp) / ry,
    cyp = (-factor * ry * xp) / rx;
  const cx = cos * cxp - sin * cyp + (x1 + x2) / 2,
    cy = sin * cxp + cos * cyp + (y1 + y2) / 2;
  const angleOf = (ux, uy, vx, vy) =>
    Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
  const start = angleOf(1, 0, (xp - cxp) / rx, (yp - cyp) / ry);
  let delta = angleOf(
    (xp - cxp) / rx,
    (yp - cyp) / ry,
    (-xp - cxp) / rx,
    (-yp - cyp) / ry,
  );
  if (!sweep && delta > 0) delta -= 2 * Math.PI;
  if (sweep && delta < 0) delta += 2 * Math.PI;
  const segments = Math.ceil(Math.abs(delta) / (Math.PI / 2));
  const step = delta / segments,
    k = (4 / 3) * Math.tan(step / 4);
  const at = (t) => [
    cx + rx * Math.cos(t) * cos - ry * Math.sin(t) * sin,
    cy + rx * Math.cos(t) * sin + ry * Math.sin(t) * cos,
  ];
  const tangent = (t) => [
    -rx * Math.sin(t) * cos - ry * Math.cos(t) * sin,
    -rx * Math.sin(t) * sin + ry * Math.cos(t) * cos,
  ];
  const curves = [];
  for (let i = 0; i < segments; i++) {
    const a = start + i * step,
      b = a + step;
    const [ax, ay] = at(a),
      [bx, by] = at(b),
      [tax, tay] = tangent(a),
      [tbx, tby] = tangent(b);
    curves.push([ax + k * tax, ay + k * tay, bx - k * tbx, by - k * tby, bx, by]);
  }
  return curves;
}

function swiftPath(d, parsePath) {
  const lines = [];
  let x = 0,
    y = 0,
    sx = 0,
    sy = 0,
    lastCubic = null,
    lastQuad = null;
  for (const [cmd, ...a] of parsePath(d)) {
    const rel = cmd === cmd.toLowerCase(),
      ox = rel ? x : 0,
      oy = rel ? y : 0;
    switch (cmd.toLowerCase()) {
      case "m":
        x = ox + a[0];
        y = oy + a[1];
        sx = x;
        sy = y;
        lines.push(`path.move(to: ${point(x, y)})`);
        break;
      case "l":
        x = ox + a[0];
        y = oy + a[1];
        lines.push(`path.addLine(to: ${point(x, y)})`);
        break;
      case "h":
        x = (rel ? x : 0) + a[0];
        lines.push(`path.addLine(to: ${point(x, y)})`);
        break;
      case "v":
        y = (rel ? y : 0) + a[0];
        lines.push(`path.addLine(to: ${point(x, y)})`);
        break;
      case "c": {
        const c = [ox + a[0], oy + a[1], ox + a[2], oy + a[3], ox + a[4], oy + a[5]];
        lines.push(`path.addCurve(to: ${point(c[4], c[5])}, control1: ${point(c[0], c[1])}, control2: ${point(c[2], c[3])})`);
        lastCubic = [c[2], c[3]];
        x = c[4];
        y = c[5];
        continue;
      }
      case "s": {
        const [px, py] = lastCubic ? [2 * x - lastCubic[0], 2 * y - lastCubic[1]] : [x, y];
        const c = [ox + a[0], oy + a[1], ox + a[2], oy + a[3]];
        lines.push(`path.addCurve(to: ${point(c[2], c[3])}, control1: ${point(px, py)}, control2: ${point(c[0], c[1])})`);
        lastCubic = [c[0], c[1]];
        x = c[2];
        y = c[3];
        continue;
      }
      case "q": {
        const c = [ox + a[0], oy + a[1], ox + a[2], oy + a[3]];
        lines.push(`path.addQuadCurve(to: ${point(c[2], c[3])}, control: ${point(c[0], c[1])})`);
        lastQuad = [c[0], c[1]];
        x = c[2];
        y = c[3];
        continue;
      }
      case "t": {
        const [px, py] = lastQuad ? [2 * x - lastQuad[0], 2 * y - lastQuad[1]] : [x, y];
        x = ox + a[0];
        y = oy + a[1];
        lines.push(`path.addQuadCurve(to: ${point(x, y)}, control: ${point(px, py)})`);
        lastQuad = [px, py];
        continue;
      }
      case "a": {
        const tx = ox + a[5],
          ty = oy + a[6];
        for (const c of arcCurves(x, y, a[0], a[1], a[2], a[3], a[4], tx, ty))
          lines.push(`path.addCurve(to: ${point(c[4], c[5])}, control1: ${point(c[0], c[1])}, control2: ${point(c[2], c[3])})`);
        x = tx;
        y = ty;
        break;
      }
      case "z":
        lines.push("path.closeSubpath()");
        x = sx;
        y = sy;
        break;
    }
    lastCubic = null;
    lastQuad = null;
  }
  return lines;
}

function nodeLines([tag, attrs], parsePath) {
  const n = (k) => +(attrs[k] ?? 0);
  switch (tag) {
    case "path":
      return swiftPath(attrs.d, parsePath);
    case "line":
      return [`path.move(to: ${point(n("x1"), n("y1"))})`, `path.addLine(to: ${point(n("x2"), n("y2"))})`];
    case "circle":
      return [`path.addEllipse(in: CGRect(x: ${num(n("cx") - n("r"))}, y: ${num(n("cy") - n("r"))}, width: ${num(2 * n("r"))}, height: ${num(2 * n("r"))}))`];
    case "rect":
      return [`path.addRoundedRect(in: CGRect(x: ${num(n("x"))}, y: ${num(n("y"))}, width: ${num(n("width"))}, height: ${num(n("height"))}), cornerSize: CGSize(width: ${num(n("rx"))}, height: ${num(n("ry") || n("rx"))}))`];
    case "polyline":
    case "polygon": {
      const pts = attrs.points.trim().split(/[\s,]+/).map(Number);
      const out = [`path.move(to: ${point(pts[0], pts[1])})`];
      for (let i = 2; i < pts.length; i += 2) out.push(`path.addLine(to: ${point(pts[i], pts[i + 1])})`);
      if (tag === "polygon") out.push("path.closeSubpath()");
      return out;
    }
    default:
      throw new Error(`Unknown icon shape ${tag}`);
  }
}

/** [icons] maps a Swift case name to Lucide's icon nodes. */
export function swiftIcons({ icons, parsePath, HEAD }) {
  const cases = Object.keys(icons);
  return `// ${HEAD}
//
// Lucide icons, drawn on Lucide's 24 by 24 grid with a stroke of 2, as the
// app's icon font draws them.

import SwiftUI

enum AnchorIcon: CaseIterable {
${cases.map((c) => `    case ${c}`).join("\n")}

    var path: Path {
        var path = Path()
        switch self {
${cases.map((c) => `        case .${c}:\n${icons[c].flatMap((node) => nodeLines(node, parsePath)).map((l) => `            ${l}`).join("\n")}`).join("\n")}
        }
        return path
    }
}
`;
}
