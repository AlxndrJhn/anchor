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
