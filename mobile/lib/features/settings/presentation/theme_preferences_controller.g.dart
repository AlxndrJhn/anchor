// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_preferences_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

final class ThemeModeControllerProvider
    extends $NotifierProvider<ThemeModeController, ThemeMode> {
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeControllerHash() =>
    r'3505b469be03c314188ac81a151edbfec1df9c67';

abstract class _$ThemeModeController extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DisplayDensityController)
final displayDensityControllerProvider = DisplayDensityControllerProvider._();

final class DisplayDensityControllerProvider
    extends $NotifierProvider<DisplayDensityController, DisplayDensity> {
  DisplayDensityControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayDensityControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayDensityControllerHash();

  @$internal
  @override
  DisplayDensityController create() => DisplayDensityController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayDensity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayDensity>(value),
    );
  }
}

String _$displayDensityControllerHash() =>
    r'16354c2d0330ce24a02fbf1262abe11bb9f1cd62';

abstract class _$DisplayDensityController extends $Notifier<DisplayDensity> {
  DisplayDensity build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DisplayDensity, DisplayDensity>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DisplayDensity, DisplayDensity>,
              DisplayDensity,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A colour scheme id: [anchorSchemeId] or one of `appSchemes`.

@ProviderFor(ColorSchemeController)
final colorSchemeControllerProvider = ColorSchemeControllerProvider._();

/// A colour scheme id: [anchorSchemeId] or one of `appSchemes`.
final class ColorSchemeControllerProvider
    extends $NotifierProvider<ColorSchemeController, String> {
  /// A colour scheme id: [anchorSchemeId] or one of `appSchemes`.
  ColorSchemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'colorSchemeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$colorSchemeControllerHash();

  @$internal
  @override
  ColorSchemeController create() => ColorSchemeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$colorSchemeControllerHash() =>
    r'6a6508f76bf2f39351f638a6d6c84c1a938c4ea5';

/// A colour scheme id: [anchorSchemeId] or one of `appSchemes`.

abstract class _$ColorSchemeController extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AppStyleController)
final appStyleControllerProvider = AppStyleControllerProvider._();

final class AppStyleControllerProvider
    extends $NotifierProvider<AppStyleController, AppStyle> {
  AppStyleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appStyleControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appStyleControllerHash();

  @$internal
  @override
  AppStyleController create() => AppStyleController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppStyle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppStyle>(value),
    );
  }
}

String _$appStyleControllerHash() =>
    r'5d044fa41baa1593b70fa421d42ce6b82d0a2edf';

abstract class _$AppStyleController extends $Notifier<AppStyle> {
  AppStyle build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppStyle, AppStyle>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppStyle, AppStyle>,
              AppStyle,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The custom theme pasted in Settings, over the colour scheme; null for none.

@ProviderFor(CustomThemeController)
final customThemeControllerProvider = CustomThemeControllerProvider._();

/// The custom theme pasted in Settings, over the colour scheme; null for none.
final class CustomThemeControllerProvider
    extends $NotifierProvider<CustomThemeController, CustomTheme?> {
  /// The custom theme pasted in Settings, over the colour scheme; null for none.
  CustomThemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customThemeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customThemeControllerHash();

  @$internal
  @override
  CustomThemeController create() => CustomThemeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomTheme? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomTheme?>(value),
    );
  }
}

String _$customThemeControllerHash() =>
    r'aa193b11e2d05d62d12c532bf2997187524d0e8f';

/// The custom theme pasted in Settings, over the colour scheme; null for none.

abstract class _$CustomThemeController extends $Notifier<CustomTheme?> {
  CustomTheme? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CustomTheme?, CustomTheme?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CustomTheme?, CustomTheme?>,
              CustomTheme?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
