import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'tokens/app_schemes.dart';

/// A custom theme pasted as JSON in Settings › Appearance. The same JSON
/// works on the web (web/lib/design/custom-theme.ts); README.md, "Custom
/// themes", describes it.
///
///   { "name": "My theme", "light": { "background": "#fff", … }, "dark": … }
///
/// Every key is optional except that one of light and dark must be there. A
/// mode's colours are [SchemePalette.fields]; a missing one keeps the chosen
/// scheme's colour.
@immutable
class CustomTheme {
  const CustomTheme({this.name, this.light, this.dark});

  final String? name;
  final Map<String, Color>? light;
  final Map<String, Color>? dark;

  Map<String, Color>? of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// [base] with this theme's colours for [brightness] in place of its own.
  SchemePalette merge(SchemePalette base, Brightness brightness) =>
      base.withColors(of(brightness) ?? const {});

  /// The theme as JSON, in the form [parseCustomTheme] reads.
  Map<String, Object> toJson() => {
    'name': ?name,
    if (light != null) 'light': _colorsToJson(light!),
    if (dark != null) 'dark': _colorsToJson(dark!),
  };

  /// The JSON, as one line: also what a theme is stored and compared as.
  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is CustomTheme && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// What [parseCustomTheme] makes of some text: a theme, or what's wrong.
class CustomThemeResult {
  const CustomThemeResult.ok(CustomTheme this.theme) : errors = const [];
  const CustomThemeResult.failed(this.errors) : theme = null;

  final CustomTheme? theme;
  final List<String> errors;

  bool get isOk => theme != null;
}

const _topLevelKeys = ['name', 'light', 'dark'];
const _modes = ['light', 'dark'];
final _colorPattern = RegExp(
  r'^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$',
  caseSensitive: false,
);

/// #rgb, #rrggbb or #rrggbbaa as a [Color], or null.
Color? parseThemeColor(String value) {
  if (!_colorPattern.hasMatch(value)) return null;
  var hex = value.substring(1);
  if (hex.length == 3) hex = hex.split('').map((d) => '$d$d').join();
  final rgb = int.parse(hex.substring(0, 6), radix: 16);
  final alpha = hex.length == 8 ? int.parse(hex.substring(6), radix: 16) : 255;
  return Color((alpha << 24) | rgb);
}

/// [color] as lower-case #rrggbb, or #rrggbbaa when it isn't opaque.
String themeColorToHex(Color color) {
  final argb = color.toARGB32();
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final alpha = argb >>> 24;
  return alpha == 255
      ? '#$rgb'
      : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
}

Map<String, String> _colorsToJson(Map<String, Color> colors) => {
  for (final field in SchemePalette.fields)
    if (colors[field] != null) field: themeColorToHex(colors[field]!),
};

/// The closest of [options] to [key], when it is a likely typo.
String? _closest(String key, List<String> options) {
  int distance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final row = [i];
      for (var j = 1; j <= b.length; j++) {
        row.add(
          [
            previous[j] + 1,
            row[j - 1] + 1,
            previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
          ].reduce((x, y) => x < y ? x : y),
        );
      }
      previous = row;
    }
    return previous[b.length];
  }

  String? best;
  var bestDistance = 3;
  for (final option in options) {
    final d = distance(key.toLowerCase(), option.toLowerCase());
    if (d < bestDistance) {
      best = option;
      bestDistance = d;
    }
  }
  return best;
}

String _unknownKey(String path, String key, List<String> options) {
  final guess = _closest(key, options);
  return '$path: unknown key${guess != null ? ' (did you mean "$guess"?)' : ''}'
      '; expected one of ${options.join(', ')}';
}

/// Reads and checks a custom theme, listing every problem it finds, in the
/// web app's words.
CustomThemeResult parseCustomTheme(String text) {
  Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (error) {
    return CustomThemeResult.failed(['Not valid JSON: ${error.message}']);
  }
  if (json is! Map<String, dynamic>) {
    return const CustomThemeResult.failed([
      'The theme must be a JSON object, like {"dark": {…}}',
    ]);
  }

  final errors = <String>[];
  for (final key in json.keys) {
    if (!_topLevelKeys.contains(key)) {
      errors.add(_unknownKey(key, key, _topLevelKeys));
    }
  }

  String? name;
  final rawName = json['name'];
  if (json.containsKey('name')) {
    if (rawName is String) {
      name = rawName;
    } else {
      errors.add('name: must be a string');
    }
  }

  final palettes = <String, Map<String, Color>>{};
  for (final mode in _modes) {
    if (!json.containsKey(mode)) continue;
    final colors = json[mode];
    if (colors is! Map<String, dynamic>) {
      errors.add('$mode: must be an object of colours');
      continue;
    }
    final palette = <String, Color>{};
    for (final MapEntry(:key, :value) in colors.entries) {
      if (!SchemePalette.fields.contains(key)) {
        errors.add(_unknownKey('$mode.$key', key, SchemePalette.fields));
        continue;
      }
      final color = value is String ? parseThemeColor(value) : null;
      if (color != null) {
        palette[key] = color;
      } else {
        errors.add(
          '$mode.$key: ${jsonEncode(value)} is not a colour; '
          'use #rgb, #rrggbb or #rrggbbaa',
        );
      }
    }
    palettes[mode] = palette;
  }

  if (!json.containsKey('light') && !json.containsKey('dark')) {
    errors.add('Give at least one of "light" or "dark"');
  }

  if (errors.isNotEmpty) return CustomThemeResult.failed(errors);
  return CustomThemeResult.ok(
    CustomTheme(name: name, light: palettes['light'], dark: palettes['dark']),
  );
}

/// A scheme, with [custom] over it, as custom theme JSON to start from.
String themeAsJson(AppScheme scheme, CustomTheme? custom) {
  Map<String, String> mode(Brightness brightness) {
    final palette =
        custom?.merge(scheme.of(brightness), brightness) ??
        scheme.of(brightness);
    return _colorsToJson(palette.toMap());
  }

  return const JsonEncoder.withIndent('  ').convert({
    'name': custom?.name ?? scheme.name,
    'light': mode(Brightness.light),
    'dark': mode(Brightness.dark),
  });
}
