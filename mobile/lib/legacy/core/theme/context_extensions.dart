import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_color_tokens.dart';
import '../../../core/theme/tokens/app_dimensions.dart';

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
}
