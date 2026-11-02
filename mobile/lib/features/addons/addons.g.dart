// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'addons.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(addonsRepository)
final addonsRepositoryProvider = AddonsRepositoryProvider._();

final class AddonsRepositoryProvider
    extends
        $FunctionalProvider<
          AddonsRepository,
          AddonsRepository,
          AddonsRepository
        >
    with $Provider<AddonsRepository> {
  AddonsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addonsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addonsRepositoryHash();

  @$internal
  @override
  $ProviderElement<AddonsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AddonsRepository create(Ref ref) {
    return addonsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddonsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddonsRepository>(value),
    );
  }
}

String _$addonsRepositoryHash() => r'e3b5fbb8179386895c60a06a02ec19427e3ad526';

/// The signed-in person's addons. Kept on the device, so the app starts in
/// their colours, and fetched again when the app starts and comes back.

@ProviderFor(AddonsController)
final addonsControllerProvider = AddonsControllerProvider._();

/// The signed-in person's addons. Kept on the device, so the app starts in
/// their colours, and fetched again when the app starts and comes back.
final class AddonsControllerProvider
    extends $NotifierProvider<AddonsController, List<InstalledAddon>> {
  /// The signed-in person's addons. Kept on the device, so the app starts in
  /// their colours, and fetched again when the app starts and comes back.
  AddonsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addonsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addonsControllerHash();

  @$internal
  @override
  AddonsController create() => AddonsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<InstalledAddon> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<InstalledAddon>>(value),
    );
  }
}

String _$addonsControllerHash() => r'cd712e517f606aaa9feb3a6f894a827534702191';

/// The signed-in person's addons. Kept on the device, so the app starts in
/// their colours, and fetched again when the app starts and comes back.

abstract class _$AddonsController extends $Notifier<List<InstalledAddon>> {
  List<InstalledAddon> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<InstalledAddon>, List<InstalledAddon>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<InstalledAddon>, List<InstalledAddon>>,
              List<InstalledAddon>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What the app is drawn with: the addons' themes under the custom theme.

@ProviderFor(appCustomTheme)
final appCustomThemeProvider = AppCustomThemeProvider._();

/// What the app is drawn with: the addons' themes under the custom theme.

final class AppCustomThemeProvider
    extends $FunctionalProvider<CustomTheme?, CustomTheme?, CustomTheme?>
    with $Provider<CustomTheme?> {
  /// What the app is drawn with: the addons' themes under the custom theme.
  AppCustomThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appCustomThemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appCustomThemeHash();

  @$internal
  @override
  $ProviderElement<CustomTheme?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CustomTheme? create(Ref ref) {
    return appCustomTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomTheme? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomTheme?>(value),
    );
  }
}

String _$appCustomThemeHash() => r'08ff1a1db9c37a102c1f713c87480f0aca3b9a0e';
