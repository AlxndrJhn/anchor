import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_radius.dart';
import 'app_schemes.dart';

/// The look chosen in Settings › Style, on top of the colour scheme. The ids
/// match the web app's.
enum AppStyle {
  standard('default', 'Default', 'Anchor as designed'),
  skeuomorphism('skeuomorphism', 'Skeuomorphism', 'Paper, linen and depth'),
  neoBrutalism(
    'neo-brutalism',
    'Neo-Brutalism',
    'Thick outlines, hard shadows',
  ),
  lofi('lofi', 'Lo-fi', 'A pencil-and-paper prototype');

  const AppStyle(this.id, this.label, this.subtitle);

  final String id;
  final String label;
  final String subtitle;

  static AppStyle fromId(String? id) => AppStyle.values.firstWhere(
    (style) => style.id == id,
    orElse: () => AppStyle.standard,
  );
}

/// Anchor's own colour scheme, which uses the hand-tuned palette.
const anchorSchemeId = 'anchor';

/// Anchor's own colours as a scheme: its swatch in Settings, and what a
/// custom theme falls back to over Anchor.
const anchorScheme = AppScheme(
  id: anchorSchemeId,
  name: 'Anchor+',
  light: SchemePalette(
    background: AppPalette.bgLight,
    card: AppPalette.surfaceLight,
    sidebar: AppPalette.gradientLightBottom,
    muted: AppPalette.shimmerBaseLight,
    foreground: AppPalette.slate,
    mutedForeground: AppPalette.slateBlue,
    accent: AppPalette.burntOrange,
    accentStrong: AppPalette.burntOrange,
    accentInk: AppPalette.burntOrange,
    border: AppPalette.shimmerBaseLight,
    divider: AppPalette.shimmerBaseLight,
    input: AppPalette.slateBlue,
    destructive: Color(0xFFD32F2F),
  ),
  dark: SchemePalette(
    background: AppPalette.bgDark,
    card: AppPalette.surfaceDark,
    sidebar: AppPalette.bgDark,
    muted: AppPalette.shimmerBaseDark,
    foreground: AppPalette.offWhite,
    mutedForeground: AppPalette.slateBlue,
    accent: AppPalette.burntOrange,
    accentStrong: AppPalette.burntOrange,
    accentInk: AppPalette.burntOrange,
    border: AppPalette.shimmerBaseDark,
    divider: AppPalette.shimmerBaseDark,
    input: AppPalette.slateBlue,
    destructive: Color(0xFFEF5350),
  ),
);

AppScheme? schemeById(String id) {
  for (final scheme in appSchemes) {
    if (scheme.id == id) return scheme;
  }
  return null;
}

/// How the current [AppStyle] draws note cards and page backgrounds.
@immutable
class AppStyleTokens extends ThemeExtension<AppStyleTokens> {
  const AppStyleTokens({
    required this.style,
    required this.cardRadius,
    required this.cardSide,
    required this.cardShadows,
    this.pattern,
    this.noteFill,
  });

  final AppStyle style;
  final BorderRadius cardRadius;
  final BorderSide cardSide;
  final List<BoxShadow> cardShadows;

  /// The colour of the page texture (linen or dot grid), if the style has one.
  final Color? pattern;

  /// A plain note's colour, when the scheme gives one.
  final Color? noteFill;

  /// Lo-fi draws every note as plain paper with grey pictures.
  bool get plainNotes => style == AppStyle.lofi;

  static const standard = AppStyleTokens(
    style: AppStyle.standard,
    cardRadius: AppRadius.lgBorder,
    cardSide: BorderSide.none,
    cardShadows: [],
  );

  /// Lo-fi's hand-drawn corners, as on the web.
  static const wobbly = BorderRadius.only(
    topLeft: Radius.elliptical(255, 12),
    topRight: Radius.elliptical(12, 225),
    bottomRight: Radius.elliptical(225, 12),
    bottomLeft: Radius.elliptical(12, 255),
  );

  factory AppStyleTokens.of(
    AppStyle style,
    Color ink,
    Brightness brightness, {
    Color? noteFill,
  }) => AppStyleTokens._of(style, ink, brightness).copyWith(noteFill: noteFill);

  factory AppStyleTokens._of(AppStyle style, Color ink, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (style) {
      AppStyle.standard => standard,
      AppStyle.skeuomorphism => AppStyleTokens(
        style: style,
        cardRadius: const BorderRadius.all(Radius.circular(10)),
        cardSide: BorderSide(color: ink.withValues(alpha: 0.08)),
        cardShadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.28),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
        pattern: (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.035 : 0.045,
        ),
      ),
      AppStyle.neoBrutalism => AppStyleTokens(
        style: style,
        cardRadius: const BorderRadius.all(Radius.circular(6)),
        cardSide: BorderSide(color: ink, width: 2),
        cardShadows: [BoxShadow(color: ink, offset: const Offset(4, 4))],
      ),
      AppStyle.lofi => AppStyleTokens(
        style: style,
        cardRadius: wobbly,
        cardSide: BorderSide(color: ink.withValues(alpha: 0.75), width: 1.75),
        cardShadows: const [],
        pattern: ink.withValues(alpha: 0.14),
      ),
    };
  }

  @override
  AppStyleTokens copyWith({
    AppStyle? style,
    BorderRadius? cardRadius,
    BorderSide? cardSide,
    List<BoxShadow>? cardShadows,
    Color? pattern,
    Color? noteFill,
  }) => AppStyleTokens(
    style: style ?? this.style,
    cardRadius: cardRadius ?? this.cardRadius,
    cardSide: cardSide ?? this.cardSide,
    cardShadows: cardShadows ?? this.cardShadows,
    pattern: pattern ?? this.pattern,
    noteFill: noteFill ?? this.noteFill,
  );

  @override
  AppStyleTokens lerp(AppStyleTokens? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Turns pictures grey for Lo-fi.
const grayscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);
