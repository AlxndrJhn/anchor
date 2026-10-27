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
    r'937eac58f63ac7c9b8dcbfdd2db88da343030169';

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
    r'5b7a4c8af955c16fd57c13c62c49f8bfbb6f1fed';

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

/// The colour scheme's id: [anchorSchemeId] or one of `appSchemes`.

@ProviderFor(ColorSchemeController)
final colorSchemeControllerProvider = ColorSchemeControllerProvider._();

/// The colour scheme's id: [anchorSchemeId] or one of `appSchemes`.
final class ColorSchemeControllerProvider
    extends $NotifierProvider<ColorSchemeController, String> {
  /// The colour scheme's id: [anchorSchemeId] or one of `appSchemes`.
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
    r'49b68990cb638f369125d34b3cdb9c0c699f6ea1';

/// The colour scheme's id: [anchorSchemeId] or one of `appSchemes`.

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
    r'610f448e55401463449f9d369abc7054596de9d7';

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
    r'de338e72be5e585283a9ea4e5053175c73d91447';

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
