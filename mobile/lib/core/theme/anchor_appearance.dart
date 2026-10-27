import 'package:flutter/material.dart';

import 'tokens/anchor_tokens.dart';
import 'tokens/app_schemes.dart';
import 'tokens/app_style.dart';

/// Anchor's colours recoloured for a colour scheme and reshaped for a style,
/// as Settings › Appearance chooses them. The web does the same in
/// `web/app/styles/appearance.css`.
abstract final class AnchorAppearance {
  /// [palette] null keeps Anchor's own colours. [custom] is a custom
  /// theme's colours for this mode, by `SchemePalette` field, over the rest;
  /// what it leaves out stays as Anchor's or the scheme's.
  static AnchorColors colors(
    Brightness brightness,
    SchemePalette? palette,
    AppStyle style, {
    Map<String, Color>? custom,
  }) {
    final isDark = brightness == Brightness.dark;
    var colors = isDark ? AnchorColors.dark : AnchorColors.light;
    if (palette != null) colors = _recolor(colors, palette.toMap());
    if (custom != null) colors = _recolor(colors, custom);
    if (palette != null || custom != null || style != AppStyle.standard) {
      // A plain note takes the scheme's card colour.
      colors = colors.copyWith(
        notes: {
          ...colors.notes,
          'none': AnchorNoteColors(
            bg: colors.appSurface,
            surface: Color.alphaBlend(
              colors.appText.withValues(alpha: 0.07),
              colors.appSurface,
            ),
            border: colors.appBorder,
            pattern: colors.appSurface,
            muted: colors.appMuted,
          ),
        },
      );
    }
    colors = _reshape(colors, style, isDark);
    if (style == AppStyle.standard && isTrueBlack(colors.appPage)) {
      // Shadows vanish on a black page (OLED): outline what they'd lift
      // instead, as the web does.
      colors = colors.copyWith(
        shadowXs: [BoxShadow(color: colors.appBorder, spreadRadius: 1)],
      );
    }
    return colors;
  }

  /// Black, or so close to it that an OLED screen leaves the pixel off.
  static bool isTrueBlack(Color color) => color.computeLuminance() < 0.001;

  /// White or near-black, whichever reads on [color].
  static Color onColor(Color color) => color.computeLuminance() > 0.45
      ? const Color(0xFF1B1B1B)
      : const Color(0xFFFFFFFF);

  /// [colors] with the palette colours in [fields] (by `SchemePalette`
  /// field name) and what's drawn from them; the others stay.
  static AnchorColors _recolor(AnchorColors colors, Map<String, Color> fields) {
    final destructive = fields['destructive'];
    final accentStrong = fields['accentStrong'];
    return colors.copyWith(
      appPage: fields['background'],
      appSurface: fields['card'],
      appSidebar: fields['sidebar'],
      appSubtle: fields['muted'],
      appText: fields['foreground'],
      appMuted: fields['mutedForeground'],
      appBorder: fields['border'],
      appDivider: fields['divider'],
      appFieldLine: fields['input'],
      accentStrong: accentStrong,
      accentInk: fields['accentInk'],
      statusDanger: destructive,
      statusOnDanger: destructive == null ? null : onColor(destructive),
      checkMark: accentStrong == null ? null : onColor(accentStrong),
      appInverse: fields['foreground'],
      appOnInverse: fields['background'],
      appInverseLink: fields['accent'],
      appInverseDanger: destructive,
    );
  }

  static AnchorColors _reshape(
    AnchorColors colors,
    AppStyle style,
    bool isDark,
  ) {
    final ink = colors.appText;
    switch (style) {
      case AppStyle.standard:
        return colors;
      case AppStyle.skeuomorphism:
        BoxShadow soft(
          double alpha,
          double darkAlpha,
          double y,
          double blur, [
          double spread = 0,
        ]) => BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? darkAlpha : alpha),
          offset: Offset(0, y),
          blurRadius: blur,
          spreadRadius: spread,
        );
        final raised = [soft(0.16, 0.5, 2, 3), soft(0.28, 0.6, 10, 24, -6)];
        return colors.copyWith(
          shadowXs: [soft(0.18, 0.5, 1, 2), soft(0.1, 0.35, 2, 6)],
          shadowRaised: raised,
          shadowFloating: raised,
          shadowMenu: [soft(0.2, 0.5, 2, 4), soft(0.38, 0.6, 14, 32, -8)],
          shadowDialog: [soft(0.22, 0.5, 3, 6), soft(0.5, 0.7, 30, 60, -18)],
        );
      case AppStyle.neoBrutalism:
        // Ink outlines and hard offset shadows.
        final ring = BoxShadow(color: ink, spreadRadius: 2);
        List<BoxShadow> hard(double by) => [
          ring,
          BoxShadow(color: ink, offset: Offset(by, by), spreadRadius: 2),
        ];
        return colors.copyWith(
          appBorder: ink,
          appDivider: ink.withValues(alpha: 0.35),
          shadowXs: hard(3),
          shadowSm: [BoxShadow(color: ink, offset: const Offset(3, 3))],
          shadowEdge: [ring],
          shadowControl: [BoxShadow(color: ink, offset: const Offset(3, 3))],
          shadowRaised: hard(5),
          shadowFloating: hard(5),
          shadowMenu: hard(5),
          shadowFab: hard(5),
          shadowLift: hard(8),
          shadowDialog: hard(8),
          shadowBar: hard(6),
        );
      case AppStyle.lofi:
        // No depth, only pencil outlines; highlights in grey.
        final pencil = [
          BoxShadow(color: ink.withValues(alpha: 0.75), spreadRadius: 1.5),
        ];
        final grey = AnchorHighlight(
          fill: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE4E4E4),
          ink: colors.appMuted,
        );
        return colors.copyWith(
          shadowXs: pencil,
          shadowRaised: pencil,
          shadowFloating: pencil,
          shadowMenu: pencil,
          shadowLift: pencil,
          shadowDialog: pencil,
          shadowFab: pencil,
          shadowBar: pencil,
          shadowSm: const [],
          shadowControl: const [],
          shadowEdge: const [],
          highlights: {for (final name in colors.highlights.keys) name: grey},
        );
    }
  }
}
