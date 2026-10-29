import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../core/theme/display_density.dart';

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
