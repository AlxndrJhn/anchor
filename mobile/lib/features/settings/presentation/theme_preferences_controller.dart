import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../core/theme/custom_theme.dart';
import '../../../core/theme/display_density.dart';
import '../../../core/theme/tokens/app_style.dart';

part 'theme_preferences_controller.g.dart';

@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ref.watch(appBootstrapProvider).themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setThemeMode(mode.name);
  }
}

@Riverpod(keepAlive: true)
class DisplayDensityController extends _$DisplayDensityController {
  @override
  DisplayDensity build() => ref.watch(appBootstrapProvider).displayDensity;

  Future<void> setDensity(DisplayDensity density) async {
    state = density;
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setDisplayDensity(density.name);
  }
}

/// A colour scheme id: [anchorSchemeId] or one of `appSchemes`.
@Riverpod(keepAlive: true)
class ColorSchemeController extends _$ColorSchemeController {
  @override
  String build() => ref.watch(appBootstrapProvider).colorScheme;

  Future<void> setScheme(String scheme) async {
    state = scheme;
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setColorScheme(scheme);
  }
}

@Riverpod(keepAlive: true)
class AppStyleController extends _$AppStyleController {
  @override
  AppStyle build() => ref.watch(appBootstrapProvider).appStyle;

  Future<void> setStyle(AppStyle style) async {
    state = style;
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setAppStyle(style.id);
  }
}

/// Darker text and heavier note text, over any scheme or custom theme.
@Riverpod(keepAlive: true)
class HighContrastController extends _$HighContrastController {
  @override
  bool build() => ref.watch(appBootstrapProvider).highContrast;

  Future<void> setHighContrast(bool on) async {
    state = on;
    await ref.read(preferencesRepositoryProvider).setHighContrast(on);
  }
}

/// The custom theme pasted in Settings, over the colour scheme; null for none.
@Riverpod(keepAlive: true)
class CustomThemeController extends _$CustomThemeController {
  @override
  CustomTheme? build() => ref.watch(appBootstrapProvider).customTheme;

  /// Applies the theme in [json] and returns nothing, or returns what's
  /// wrong with it and changes nothing.
  Future<List<CustomThemeProblem>> apply(String json) async {
    final result = parseCustomTheme(json);
    if (!result.isOk) return result.problems;
    state = result.theme;
    await ref
        .read(preferencesRepositoryProvider)
        .setCustomTheme(result.theme!.encode());
    return const [];
  }

  Future<void> reset() async {
    state = null;
    await ref.read(preferencesRepositoryProvider).setCustomTheme(null);
  }
}
