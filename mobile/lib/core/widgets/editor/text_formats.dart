import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Inline text formats shared with the web client, stored on text ops as:
///
/// * `highlight`: a preset name ([highlightPresets]) or a custom `#rrggbb`;
/// * `color`: the text colour, `#rrggbb`;
/// * `font`: one of [fontOptions] (absent means the app's normal font).
///
/// Removing a format sets it to null, as in Quill.
abstract final class TextFormats {
  static const highlightKey = 'highlight';
  static const colorKey = 'color';
  static const fontKey = 'font';

  /// A `highlight` attribute with [value]; null removes it.
  static Attribute<String?> highlight(String? value) =>
      Attribute<String?>(highlightKey, AttributeScope.inline, value);

  /// A `color` attribute with [value]; null removes it.
  static Attribute<String?> color(String? value) =>
      Attribute<String?>(colorKey, AttributeScope.inline, value);

  /// A `font` attribute with [value]; null removes it.
  static Attribute<String?> font(String? value) =>
      Attribute<String?>(fontKey, AttributeScope.inline, value);
}

/// A named colour offered in a picker.
class NamedColor {
  final String name;
  final String label;
  final Color color;

  const NamedColor(this.name, this.label, this.color);

  /// The colour as stored for a text colour.
  String get hex => colorToHex(color);
}

/// Highlight presets, stored by [NamedColor.name]. The fills are the same in
/// light and dark themes, as on the web.
const highlightPresets = <NamedColor>[
  NamedColor('yellow', 'Yellow', Color(0xFFFEEA74)),
  NamedColor('green', 'Green', Color(0xFFAAF5B9)),
  NamedColor('blue', 'Blue', Color(0xFFAAE6FF)),
  NamedColor('pink', 'Pink', Color(0xFFFFC4E1)),
  NamedColor('purple', 'Purple', Color(0xFFECCFFF)),
];

/// Text colour presets, stored by [NamedColor.hex], in picker order.
const textColorPresets = <NamedColor>[
  NamedColor('red', 'Red', Color(0xFFE03131)),
  NamedColor('orange', 'Orange', Color(0xFFE8590C)),
  NamedColor('amber', 'Amber', Color(0xFFF08C00)),
  NamedColor('green', 'Green', Color(0xFF2F9E44)),
  NamedColor('teal', 'Teal', Color(0xFF0C8599)),
  NamedColor('blue', 'Blue', Color(0xFF1971C2)),
  NamedColor('purple', 'Purple', Color(0xFF7048E8)),
  NamedColor('pink', 'Pink', Color(0xFFC2255C)),
  NamedColor('gray', 'Gray', Color(0xFF868E96)),
];

/// Font choices: stored value (null = the app's font) and label.
const fontOptions = <(String?, String)>[
  (null, 'Default'),
  ('serif', 'Serif'),
  ('monospace', 'Monospace'),
  // Bundled in assets/fonts, under these family names.
  ('comic', 'Comic Sans'),
  ('handwriting', 'Handwriting'),
  ('typewriter', 'Typewriter'),
  ('rounded', 'Rounded'),
  ('slab', 'Slab'),
  ('marker', 'Marker'),
];

/// Dark ink for text on a light highlight, so it stays readable on dark
/// themes whose text is light.
const highlightInkDark = Color(0xFF1C1E26);

/// Light ink for text on a dark (custom) highlight.
const highlightInkLight = Color(0xFFFFFFFF);

final _hexPattern = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

/// Parses `#rgb` or `#rrggbb` (the `#` is optional, surrounding spaces are
/// ignored). Returns null for anything else.
Color? parseHexColor(String? input) {
  if (input == null) return null;
  final match = _hexPattern.firstMatch(input.trim());
  if (match == null) return null;
  var hex = match.group(1)!;
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// Normalises `#rgb` / `#rrggbb` input to lowercase `#rrggbb`, or null.
String? normalizeHex(String? input) {
  final color = parseHexColor(input);
  return color == null ? null : colorToHex(color);
}

/// The colour as lowercase `#rrggbb` (alpha dropped).
String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

/// The fill for a stored `highlight` value: a preset or a custom hex.
Color? highlightFill(Object? value) {
  if (value is! String) return null;
  for (final preset in highlightPresets) {
    if (preset.name == value) return preset.color;
  }
  return parseHexColor(value);
}

/// The colour for a stored `color` value.
Color? textColorValue(Object? value) =>
    value is String ? parseHexColor(value) : null;

/// The stored `font` value as a font family, or null for the app's font.
String? fontFamilyValue(Object? value) =>
    value != null && fontOptions.any((option) => option.$1 == value)
    ? value as String
    : null;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The text colour to use on [fill]: [textColor] when it reads well there,
/// otherwise dark or light ink by the fill's luminance. Light themes keep
/// their text colour on the presets; dark themes get dark ink.
Color highlightInk(Color fill, Color? textColor) {
  if (textColor != null &&
      textColor.a > 0.5 &&
      _contrast(textColor, fill) >= 4.5) {
    return textColor;
  }
  return _contrast(highlightInkDark, fill) >= _contrast(highlightInkLight, fill)
      ? highlightInkDark
      : highlightInkLight;
}

/// The style a `highlight` value paints: the fill behind the text and a
/// readable ink on it. Empty for an unknown value.
TextStyle highlightTextStyle(Object? value, {Color? textColor}) {
  final fill = highlightFill(value);
  if (fill == null) return const TextStyle();
  return TextStyle(backgroundColor: fill, color: highlightInk(fill, textColor));
}

/// The style for a run's `highlight`, `color` and `font` [attributes], as
/// laid over text drawn in [textColor]. An explicit `color` wins over the
/// highlight's ink.
TextStyle inlineFormatStyle(
  Map<String, dynamic>? attributes, {
  Color? textColor,
}) {
  if (attributes == null) return const TextStyle();
  var style = const TextStyle();
  final color = textColorValue(attributes[TextFormats.colorKey]);
  final family = fontFamilyValue(attributes[TextFormats.fontKey]);
  if (family != null) style = style.copyWith(fontFamily: family);
  if (color != null) style = style.copyWith(color: color);
  final fill = highlightFill(attributes[TextFormats.highlightKey]);
  if (fill != null) {
    style = style.copyWith(
      backgroundColor: fill,
      color: color ?? highlightInk(fill, textColor),
    );
  }
  return style;
}
