import 'package:flutter/material.dart';

import 'tokens/app_color_tokens.dart';
import 'tokens/app_dimensions.dart';
import 'tokens/app_style.dart';

extension ThemeContextX on BuildContext {
  /// Density-resolved spacing tokens. Falls back to standard values so
  /// widgets keep working under a bare MaterialApp (tests, previews).
  AppDimensions get dims =>
      Theme.of(this).extension<AppDimensions>() ?? AppDimensions.standard;

  AppColorTokens get colorTokens =>
      Theme.of(this).extension<AppColorTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColorTokens.dark
          : AppColorTokens.light);

  /// How the chosen style draws cards and page textures.
  AppStyleTokens get styleTokens =>
      Theme.of(this).extension<AppStyleTokens>() ?? AppStyleTokens.standard;
}
