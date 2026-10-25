import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'app_schemes.dart';

/// The look chosen in Settings › Appearance › Style, on top of the colour
/// scheme. The ids match the web app's.
enum AppStyle {
  standard('default'),
  skeuomorphism('skeuomorphism'),
  neoBrutalism('neo-brutalism'),
  lofi('lofi');

  const AppStyle(this.id);

  final String id;

  static AppStyle fromId(String? id) => AppStyle.values.firstWhere(
    (style) => style.id == id,
    orElse: () => AppStyle.standard,
  );

  String labelIn(AppLocalizations l10n) => switch (this) {
    AppStyle.standard => l10n.styleDefault,
    AppStyle.skeuomorphism => l10n.styleSkeuomorphism,
    AppStyle.neoBrutalism => l10n.styleNeoBrutalism,
    AppStyle.lofi => l10n.styleLofi,
  };

  String subtitleIn(AppLocalizations l10n) => switch (this) {
    AppStyle.standard => l10n.styleDefaultHelp,
    AppStyle.skeuomorphism => l10n.styleSkeuomorphismHelp,
    AppStyle.neoBrutalism => l10n.styleNeoBrutalismHelp,
    AppStyle.lofi => l10n.styleLofiHelp,
  };
}

/// Anchor's own colour scheme: the palette in `anchor_tokens.dart`.
const anchorSchemeId = 'anchor';

/// The generated scheme with [id]; null for Anchor's own or an unknown id.
AppScheme? schemeById(String? id) {
  for (final scheme in appSchemes) {
    if (scheme.id == id) return scheme;
  }
  return null;
}

/// How the current [AppStyle] shapes things: corners, the page texture, and
/// what it does to notes and pictures. Colours and shadows are in
/// `AnchorColors`, fonts in `AppTypography`; both follow the style too.
@immutable
class AnchorStyle extends ThemeExtension<AnchorStyle> {
  const AnchorStyle({this.style = AppStyle.standard, this.pattern});

  final AppStyle style;

  /// The colour of the page texture (linen or a dot grid), if any.
  final Color? pattern;

  static const standard = AnchorStyle();

  factory AnchorStyle.of(AppStyle style, Color ink, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AnchorStyle(
      style: style,
      pattern: switch (style) {
        AppStyle.skeuomorphism =>
          (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.035 : 0.045,
          ),
        AppStyle.lofi => ink.withValues(alpha: 0.14),
        _ => null,
      },
    );
  }

  /// Lo-fi draws every note as plain paper.
  bool get plainNotes => style == AppStyle.lofi;

  /// Lo-fi turns pictures grey.
  bool get grayscalePictures => style == AppStyle.lofi;

  /// [image] as this style shows pictures: grey for Lo-fi.
  Widget picture(Widget image) => grayscalePictures
      ? ColorFiltered(colorFilter: grayscaleFilter, child: image)
      : image;

  /// The new-note button is round unless the style squares it off.
  bool get roundFab =>
      style == AppStyle.standard || style == AppStyle.skeuomorphism;

  /// Lo-fi's hand-drawn corners, as on the web.
  static const wobbly = BorderRadius.only(
    topLeft: Radius.elliptical(255, 12),
    topRight: Radius.elliptical(12, 225),
    bottomRight: Radius.elliptical(225, 12),
    bottomLeft: Radius.elliptical(12, 255),
  );

  /// The corners this style draws for the design radius [radius], one of the
  /// `AnchorTokens.radius*` tokens. Pills stay pills.
  BorderRadius corners(double radius) => switch (style) {
    _ when radius >= _pill => BorderRadius.circular(radius),
    AppStyle.standard => BorderRadius.circular(radius),
    AppStyle.skeuomorphism => BorderRadius.circular(_skeuomorphism(radius)),
    AppStyle.neoBrutalism => BorderRadius.circular(_neoBrutalism(radius)),
    AppStyle.lofi => radius >= 16 ? wobbly : BorderRadius.circular(radius),
  };

  static const double _pill = 999;

  /// From the web's `appearance.css`: paper cards and notes, a softer button.
  static double _skeuomorphism(double radius) => switch (radius) {
    16 || 18 => 10,
    10 => 9,
    _ => radius,
  };

  /// Square-ish corners.
  static double _neoBrutalism(double radius) => switch (radius) {
    6 => 3,
    8 => 4,
    10 => 5,
    12 || 14 || 16 || 18 => 6,
    20 => 8,
    28 => 10,
    _ => radius,
  };

  @override
  AnchorStyle copyWith({AppStyle? style, Color? pattern}) =>
      AnchorStyle(style: style ?? this.style, pattern: pattern ?? this.pattern);

  @override
  AnchorStyle lerp(AnchorStyle? other, double t) =>
      other == null || t < 0.5 ? this : other;

  @override
  bool operator ==(Object other) =>
      other is AnchorStyle && other.style == style && other.pattern == pattern;

  @override
  int get hashCode => Object.hash(style, pattern);
}

/// Turns pictures grey for Lo-fi.
const grayscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);
