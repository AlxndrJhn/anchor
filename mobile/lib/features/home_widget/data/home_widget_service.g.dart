// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_widget_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeWidgetSync)
final homeWidgetSyncProvider = HomeWidgetSyncProvider._();

final class HomeWidgetSyncProvider
    extends $NotifierProvider<HomeWidgetSync, void> {
  HomeWidgetSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeWidgetSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeWidgetSyncHash();

  @$internal
  @override
  HomeWidgetSync create() => HomeWidgetSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$homeWidgetSyncHash() => r'bd71009fface61775fd5dd0cd007f972a11c3e16';

abstract class _$HomeWidgetSync extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Cold-start taps go through `initializeApp`.

@ProviderFor(HomeWidgetLaunchHandler)
final homeWidgetLaunchHandlerProvider = HomeWidgetLaunchHandlerProvider._();

/// Cold-start taps go through `initializeApp`.
final class HomeWidgetLaunchHandlerProvider
    extends $NotifierProvider<HomeWidgetLaunchHandler, void> {
  /// Cold-start taps go through `initializeApp`.
  HomeWidgetLaunchHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeWidgetLaunchHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeWidgetLaunchHandlerHash();

  @$internal
  @override
  HomeWidgetLaunchHandler create() => HomeWidgetLaunchHandler();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$homeWidgetLaunchHandlerHash() =>
    r'3bea2510924e43398e478a8925da9da7afe51b20';

/// Cold-start taps go through `initializeApp`.

abstract class _$HomeWidgetLaunchHandler extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
