import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anchor_density.dart';
import 'note_typography.dart';
import 'system_bars.dart';
import 'tokens/anchor_tokens.dart';

extension ThemeContextX on BuildContext {
  AnchorDensity get density =>
      Theme.of(this).extension<AnchorDensity>() ?? AnchorDensity.standard;

  NoteTypography get noteTypography =>
      Theme.of(this).extension<NoteTypography>() ??
      NoteTypography(lineHeight: density.noteLineHeight);

  AnchorColors get anchor =>
      Theme.of(this).extension<AnchorColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AnchorColors.dark
          : AnchorColors.light);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Android with the gesture bar hidden reports a zero bottom inset.
  double get safeBottom {
    final bottom = MediaQuery.paddingOf(this).bottom;
    if (MediaQuery.viewInsetsOf(this).bottom > 0) return bottom;
    return math.max(bottom, 4);
  }

  double get safeBottomAtRest =>
      math.max(MediaQuery.viewPaddingOf(this).bottom, 4);

  SystemUiOverlayStyle get systemBars => systemBarsStyle(dark: isDark);

  bool get isCupertino => switch (Theme.of(this).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
}
