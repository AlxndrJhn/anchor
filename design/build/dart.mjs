// Writes the mobile app's tokens: AnchorTokens (the same in light and dark),
// the AnchorColors ThemeExtension, the background catalog and the pattern tiles.

const camel = (path) =>
  path
    .split(".")
    .map((p, i) => (i ? p.charAt(0).toUpperCase() + p.slice(1) : p))
    .join("")
    .replace(/-(\w)/g, (_, c) => c.toUpperCase());
const num = (n) => (Number.isInteger(n) ? n.toFixed(1) : String(+n.toFixed(4)));
const str = (s) => (s == null ? "null" : `'${String(s).replace(/'/g, "\\'")}'`);

export function dartTokens({ dtcg, set, resolved, base, HEAD }) {
  const CAT = set.base.$extensions["app.anchor"].catalog;
  const color = (v) => {
    const a = Math.round((v.alpha ?? 1) * 255),
      [r, g, b] = dtcg.rgb(v);
    return `Color(0x${[a, r, g, b]
      .map((x) => x.toString(16).padStart(2, "0"))
      .join("")
      .toUpperCase()})`;
  };
  // Flutter's BoxShadow has no inset, and Flutter paints the last shadow on
  // top where CSS paints the first, so the list is reversed.
  const shadow = (v) =>
    `[${(Array.isArray(v) ? v : [v])
      .filter((s) => !s.inset)
      .reverse()
      .map(
        (s) =>
          `BoxShadow(color: ${color(s.color)}, offset: Offset(${num(s.offsetX.value)}, ${num(s.offsetY.value)}), blurRadius: ${num(s.blur.value)}, spreadRadius: ${num(s.spread.value)})`,
      )
      .join(", ")}]`;
  const weight = (v) => `FontWeight.w${dtcg.weight(v)}`;
  const style = (v) =>
    `TextStyle(fontSize: ${num(v.fontSize.value)}, height: ${v.lineHeight}, fontWeight: ${weight(v.fontWeight)}, letterSpacing: ${num(v.letterSpacing.value)})`;
  const value = (x) =>
    x.type === "color"
      ? color(x.value)
      : x.type === "dimension"
        ? num(x.value.value)
        : x.type === "duration"
          ? `Duration(milliseconds: ${x.value.unit === "s" ? x.value.value * 1000 : x.value.value})`
          : x.type === "cubicBezier"
            ? `Cubic(${x.value.join(", ")})`
            : x.type === "number"
              ? num(x.value)
              : x.type === "fontWeight"
                ? weight(x.value)
                : x.type === "typography"
                  ? style(x.value)
                  : x.type === "shadow"
                    ? shadow(x.value)
                    : null;
  const type = (x) =>
    ({
      color: "Color",
      dimension: "double",
      duration: "Duration",
      cubicBezier: "Cubic",
      number: "double",
      fontWeight: "FontWeight",
      typography: "TextStyle",
      shadow: "List<BoxShadow>",
    })[x.type];
  const doc = (x) => (x.description ? `  /// ${x.description}\n` : "");

  const constants = [...base.values()]
    .filter(
      (x) =>
        !x.deprecated &&
        !x.path.startsWith("font.family") &&
        !x.path.startsWith("color.tag.") &&
        value(x) !== null,
    )
    .map((x) =>
      x.path === "size.listDepth" || /^density\.\w+\.preview\./.test(x.path)
        ? `${doc(x)}  static const int ${camel(x.path)} = ${x.value};`
        : `${doc(x)}  static const ${type(x)} ${camel(x.path)} = ${value(x)};`,
    )
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
    const own = CAT.highlights.filter((c) =>
      R[t].has(`color.note.${n}.highlight.${c}.fill`),
    );
    const highlights = own.length
      ? `, highlights: {${own.map((c) => `'${c}': AnchorHighlight(fill: ${color(get(`highlight.${c}.fill`))})`).join(", ")}}`
      : "";
    return `AnchorNoteColors(bg: ${color(get("bg"))}, surface: ${color(get("surface"))}, border: ${color(get("border"))}, pattern: ${color(get("pattern"))}, muted: ${color(get("muted"))}${highlights})`;
  };
  const theme = (t) => `AnchorColors(
${fields.map((f) => `    ${f.name}: ${value(R[t].get(f.x.path))},`).join("\n")}
    notes: {${CAT.notes.map((n) => `\n      '${n}': ${note(t, n)},`).join("")}
    },
    highlights: {${CAT.highlights.map((c) => `\n      '${c}': AnchorHighlight(fill: ${color(R[t].get(`color.highlight.${c}.fill`).value)}, ink: ${color(R[t].get(`color.highlight.${c}.ink`).value)}),`).join("")}
    },
    tags: {${CAT.tags.map((n) => `\n      '${n}': AnchorTagColors(stored: ${color(R[t].get(`color.tag.${n}.stored`).value)}, hash: ${color(R[t].get(`color.tag.${n}.hash`).value)}, tintFill: ${color(R[t].get(`color.tag.${n}.tintFill`).value)}),`).join("")}
    },
  )`;
  const lerp = (f) =>
    f.type === "Color"
      ? `Color.lerp(${f.name}, other.${f.name}, t)!`
      : f.type === "double"
        ? `lerpDouble(${f.name}, other.${f.name}, t)!`
        : `BoxShadow.lerpList(${f.name}, other.${f.name}, t)!`;
  const background = (b) =>
    `AnchorBackground(id: ${str(b.id)}, name: ${str(b.name)}, palette: ${str(b.note)}${b.kind ? `, pattern: ${str(b.kind)}` : ""})`;

  return `// ${HEAD}
//
// AnchorTokens holds what stays the same in light and dark. AnchorColors is a
// ThemeExtension with the rest, registered on both ThemeData. Text styles carry
// size, weight, height and spacing only; the font family comes from
// AppTypography.

// dart format off

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

abstract final class AnchorTokens {
${constants}

  /// Tag colors as they are stored, by palette name.
  static const Map<String, Color> tagStored = {${CAT.tags.map((n) => `\n    '${n}': ${color(base.get(`color.tag.${n}.stored`).value)},`).join("")}
  };

  /// Highlight names in the order the pickers show them. Notes store the name.
  static const List<String> highlightNames = [${CAT.highlights.map((c) => `'${c}'`).join(", ")}];
}

@immutable
class AnchorBackground {
  const AnchorBackground({required this.id, required this.name, required this.palette, this.pattern});

  final String? id;
  final String name;
  final String palette;
  final String? pattern;
}

abstract final class AnchorBackgrounds {
  static const List<AnchorBackground> colors = [${CAT.backgrounds.colors.map((b) => `\n    ${background(b)},`).join("")}
  ];

  static const List<AnchorBackground> patterns = [${CAT.backgrounds.patterns.map((b) => `\n    ${background(b)},`).join("")}
  ];

  /// The background a note stored, or the default for an unknown or empty id.
  static AnchorBackground of(String? id) {
    for (final b in colors) {
      if (b.id == id) return b;
    }
    for (final b in patterns) {
      if (b.id == id) return b;
    }
    return colors.first;
  }
}

@immutable
class AnchorNoteColors {
  const AnchorNoteColors({required this.bg, required this.surface, required this.border, required this.pattern, required this.muted, this.highlights = const {}});

  final Color bg;
  final Color surface;
  final Color border;
  final Color pattern;
  final Color muted;

  /// Highlight colors that differ from [AnchorColors.highlights] on this note.
  final Map<String, AnchorHighlight> highlights;

  static AnchorNoteColors lerp(AnchorNoteColors a, AnchorNoteColors b, double t) => AnchorNoteColors(
        bg: Color.lerp(a.bg, b.bg, t)!,
        surface: Color.lerp(a.surface, b.surface, t)!,
        border: Color.lerp(a.border, b.border, t)!,
        pattern: Color.lerp(a.pattern, b.pattern, t)!,
        muted: Color.lerp(a.muted, b.muted, t)!,
        highlights: t < 0.5 ? a.highlights : b.highlights,
      );
}

/// A highlight: the fill behind the text and the swatch edge.
@immutable
class AnchorHighlight {
  const AnchorHighlight({required this.fill, this.ink});

  final Color fill;
  final Color? ink;

  static AnchorHighlight lerp(AnchorHighlight a, AnchorHighlight b, double t) => AnchorHighlight(
        fill: Color.lerp(a.fill, b.fill, t)!,
        ink: Color.lerp(a.ink, b.ink, t),
      );
}

/// How a tag is drawn: its stored color, the # on a chip, and its swatch fill.
@immutable
class AnchorTagColors {
  const AnchorTagColors({required this.stored, required this.hash, required this.tintFill});

  final Color stored;
  final Color hash;
  final Color tintFill;

  static AnchorTagColors lerp(AnchorTagColors a, AnchorTagColors b, double t) => AnchorTagColors(
        stored: a.stored,
        hash: Color.lerp(a.hash, b.hash, t)!,
        tintFill: Color.lerp(a.tintFill, b.tintFill, t)!,
      );
}

Map<String, V> _lerpMap<V>(Map<String, V> a, Map<String, V> b, double t, V Function(V, V, double) f) =>
    {for (final k in a.keys) k: b.containsKey(k) ? f(a[k] as V, b[k] as V, t) : a[k] as V};

@immutable
class AnchorColors extends ThemeExtension<AnchorColors> {
  const AnchorColors({
${fields.map((f) => `    required this.${f.name},`).join("\n")}
    required this.notes,
    required this.highlights,
    required this.tags,
  });

${fields.map((f) => `${f.x.description ? `  /// ${f.x.description}\n` : ""}  final ${f.type} ${f.name};`).join("\n")}

  /// Note colors by palette name; [AnchorBackgrounds] says which background
  /// uses which.
  final Map<String, AnchorNoteColors> notes;

  /// Highlight colors by name. A note can override them in [AnchorNoteColors.highlights].
  final Map<String, AnchorHighlight> highlights;

  /// Tag colors by palette name.
  final Map<String, AnchorTagColors> tags;

  /// The highlight to draw for [color] on the note palette [note].
  AnchorHighlight highlightOn(String note, String color) => notes[note]?.highlights[color] ?? highlights[color]!;

  static const light = ${theme("light")};

  static const dark = ${theme("dark")};

  @override
  AnchorColors copyWith({
${fields.map((f) => `    ${f.type}? ${f.name},`).join("\n")}
    Map<String, AnchorNoteColors>? notes,
    Map<String, AnchorHighlight>? highlights,
    Map<String, AnchorTagColors>? tags,
  }) =>
      AnchorColors(
${fields.map((f) => `        ${f.name}: ${f.name} ?? this.${f.name},`).join("\n")}
        notes: notes ?? this.notes,
        highlights: highlights ?? this.highlights,
        tags: tags ?? this.tags,
      );

  @override
  AnchorColors lerp(ThemeExtension<AnchorColors>? other, double t) {
    if (other is! AnchorColors) return this;
    return AnchorColors(
${fields.map((f) => `      ${f.name}: ${lerp(f)},`).join("\n")}
      notes: _lerpMap(notes, other.notes, t, AnchorNoteColors.lerp),
      highlights: _lerpMap(highlights, other.highlights, t, AnchorHighlight.lerp),
      tags: _lerpMap(tags, other.tags, t, AnchorTagColors.lerp),
    );
  }
}
`;
}

// SVG shapes as Flutter Path calls ------------------------------------------------

const NUMBER = /^[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?/;
export function parsePath(d) {
  const out = [];
  let i = 0;
  const skip = () => {
    while (i < d.length && /[\s,]/.test(d[i])) i++;
  };
  const number = () => {
    skip();
    const m = d.slice(i).match(NUMBER);
    if (!m) throw new Error(`Bad path near "${d.slice(i, i + 12)}"`);
    i += m[0].length;
    return parseFloat(m[0]);
  };
  const flag = () => {
    skip();
    const f = d[i++];
    if (f !== "0" && f !== "1") throw new Error(`Bad arc flag in "${d}"`);
    return f === "1";
  };
  const ARGS = { m: 2, l: 2, h: 1, v: 1, c: 6, s: 4, q: 4, t: 2, a: 7, z: 0 };
  let cmd = null;
  while (true) {
    skip();
    if (i >= d.length) break;
    if (/[a-zA-Z]/.test(d[i])) cmd = d[i++];
    else if (!cmd) throw new Error(`Bad path "${d}"`);
    const lower = cmd.toLowerCase();
    if (lower === "z") {
      out.push([cmd]);
      continue;
    }
    const args =
      lower === "a"
        ? [number(), number(), number(), flag(), flag(), number(), number()]
        : Array.from({ length: ARGS[lower] }, number);
    out.push([cmd, ...args]);
    // Extra pairs after a move are lines.
    if (cmd === "m") cmd = "l";
    if (cmd === "M") cmd = "L";
  }
  return out;
}

function pathCalls(d) {
  const calls = [];
  let x = 0,
    y = 0,
    sx = 0,
    sy = 0,
    lastC = null,
    lastQ = null;
  const p = (a, b) => `${num(a)}, ${num(b)}`;
  for (const [cmd, ...a] of parsePath(d)) {
    const rel = cmd === cmd.toLowerCase(),
      ox = rel ? x : 0,
      oy = rel ? y : 0;
    const c = cmd.toLowerCase();
    let nextC = null,
      nextQ = null;
    if (c === "m") {
      x = ox + a[0];
      y = oy + a[1];
      sx = x;
      sy = y;
      calls.push(`moveTo(${p(x, y)})`);
    } else if (c === "l") {
      x = ox + a[0];
      y = oy + a[1];
      calls.push(`lineTo(${p(x, y)})`);
    } else if (c === "h") {
      x = (rel ? x : 0) + a[0];
      calls.push(`lineTo(${p(x, y)})`);
    } else if (c === "v") {
      y = (rel ? y : 0) + a[0];
      calls.push(`lineTo(${p(x, y)})`);
    } else if (c === "c" || c === "s") {
      let x1, y1, x2, y2, ex, ey;
      if (c === "c") [x1, y1, x2, y2, ex, ey] = [ox + a[0], oy + a[1], ox + a[2], oy + a[3], ox + a[4], oy + a[5]];
      else {
        [x1, y1] = lastC ? [2 * x - lastC[0], 2 * y - lastC[1]] : [x, y];
        [x2, y2, ex, ey] = [ox + a[0], oy + a[1], ox + a[2], oy + a[3]];
      }
      calls.push(`cubicTo(${p(x1, y1)}, ${p(x2, y2)}, ${p(ex, ey)})`);
      nextC = [x2, y2];
      x = ex;
      y = ey;
    } else if (c === "q" || c === "t") {
      let x1, y1, ex, ey;
      if (c === "q") [x1, y1, ex, ey] = [ox + a[0], oy + a[1], ox + a[2], oy + a[3]];
      else {
        [x1, y1] = lastQ ? [2 * x - lastQ[0], 2 * y - lastQ[1]] : [x, y];
        [ex, ey] = [ox + a[0], oy + a[1]];
      }
      calls.push(`quadraticBezierTo(${p(x1, y1)}, ${p(ex, ey)})`);
      nextQ = [x1, y1];
      x = ex;
      y = ey;
    } else if (c === "a") {
      const [rx, ry, rotation, large, sweep, ex, ey] = a;
      x = ox + ex;
      y = oy + ey;
      calls.push(
        `arcToPoint(Offset(${p(x, y)}), radius: Radius.elliptical(${p(rx, ry)}), rotation: ${num(rotation)}, largeArc: ${large}, clockwise: ${sweep})`,
      );
    } else if (c === "z") {
      calls.push("close()");
      x = sx;
      y = sy;
    }
    lastC = nextC;
    lastQ = nextQ;
  }
  return calls;
}

function shapeCalls([tag, attrs]) {
  const n = (k, fallback = 0) => (attrs[k] == null ? fallback : parseFloat(attrs[k]));
  if (tag === "path") return pathCalls(attrs.d);
  if (tag === "circle")
    return [`addOval(Rect.fromCircle(center: Offset(${num(n("cx"))}, ${num(n("cy"))}), radius: ${num(n("r"))}))`];
  if (tag === "ellipse")
    return [`addOval(Rect.fromCenter(center: Offset(${num(n("cx"))}, ${num(n("cy"))}), width: ${num(2 * n("rx"))}, height: ${num(2 * n("ry"))}))`];
  if (tag === "line") return [`moveTo(${num(n("x1"))}, ${num(n("y1"))})`, `lineTo(${num(n("x2"))}, ${num(n("y2"))})`];
  if (tag === "rect") {
    const rx = n("rx", n("ry")),
      ry = n("ry", rx);
    return [
      `addRRect(RRect.fromRectXY(Rect.fromLTWH(${num(n("x"))}, ${num(n("y"))}, ${num(n("width"))}, ${num(n("height"))}), ${num(rx)}, ${num(ry)}))`,
    ];
  }
  if (tag === "polyline" || tag === "polygon") {
    const pts = attrs.points.trim().split(/[\s,]+/).map(parseFloat);
    const calls = [];
    for (let k = 0; k < pts.length; k += 2) calls.push(`${k ? "lineTo" : "moveTo"}(${num(pts[k])}, ${num(pts[k + 1])})`);
    if (tag === "polygon") calls.push("close()");
    return calls;
  }
  throw new Error(`No Dart for <${tag}>`);
}

/// The note pattern tiles, drawn the way web/app/styles/notes.css draws them.
export function dartPatterns({ set, HEAD, iconNodes }) {
  const CAT = set.base.$extensions["app.anchor"].catalog;
  const kinds = CAT.backgrounds.patterns.map((b) => b.kind);
  const icons = kinds.filter((k) => k.startsWith("icon:"));
  const iconName = (kind) => kind.split(":")[1];
  const fn = (kind) => `_${camel(iconName(kind).replace(/-/g, "."))}`;
  const iconPaths = icons
    .map((kind) => {
      const calls = iconNodes[iconName(kind)].flatMap(shapeCalls);
      return `  static final Path ${fn(kind)} = Path()\n${calls.map((c) => `    ..${c}`).join("\n")};`;
    })
    .join("\n\n");
  const iconCases = icons
    .map((kind) => {
      const rotation = parseFloat(kind.split(":")[2]) || 0;
      return `      case '${kind}':\n        _icons(canvas, ${fn(kind)}, ${num(rotation)}, color);`;
    })
    .join("\n");

  return `// ${HEAD}
//
// One tile of each note pattern, in its own coordinates. Tile it with
// [AnchorPatterns.tileSize] and draw it in the note palette's pattern color.

// dart format off

import 'dart:math' as math;

import 'package:flutter/painting.dart';

abstract final class AnchorPatterns {
  static Size tileSize(String kind) => switch (kind) {
        'dots' => const Size(20, 20),
        'waves' => const Size(40, 40),
        'grid' || 'lines' => const Size(24, 24),
        _ => const Size(60, 120),
      };

  static void paintTile(Canvas canvas, String kind, Color color) {
    switch (kind) {
      case 'dots':
        canvas.drawCircle(const Offset(10, 10), 2, Paint()..color = color);
      case 'grid':
        final line = _stroke(color, 1);
        canvas.drawLine(const Offset(0.5, 0), const Offset(0.5, 24), line);
        canvas.drawLine(const Offset(0, 0.5), const Offset(24, 0.5), line);
      case 'lines':
        canvas.drawLine(const Offset(0, 23.5), const Offset(24, 23.5), _stroke(color, 1));
      case 'waves':
        canvas.drawPath(
          Path()
            ..moveTo(0, 20)
            ..quadraticBezierTo(10, 10, 20, 20)
            ..quadraticBezierTo(30, 30, 40, 20),
          _stroke(color, 2),
        );
${iconCases}
    }
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // Three icons per tile: one at (8, 8), two at y 68.
  static void _icons(Canvas canvas, Path icon, double rotation, Color color) {
    final paint = _stroke(color, 2);
    for (final at in const [Offset(8, 8), Offset(38, 68), Offset(-22, 68)]) {
      canvas
        ..save()
        ..translate(at.dx + 12, at.dy + 12)
        ..rotate(rotation * math.pi / 180)
        ..translate(-12, -12)
        ..drawPath(icon, paint)
        ..restore();
    }
  }

${iconPaths}
}
`;
}
