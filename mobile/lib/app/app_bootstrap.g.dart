// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Overridden in `main` with what `initializeApp` read.

@ProviderFor(appBootstrap)
final appBootstrapProvider = AppBootstrapProvider._();

/// Overridden in `main` with what `initializeApp` read.

final class AppBootstrapProvider
    extends $FunctionalProvider<AppBootstrap, AppBootstrap, AppBootstrap>
    with $Provider<AppBootstrap> {
  /// Overridden in `main` with what `initializeApp` read.
  AppBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBootstrapHash();

  @$internal
  @override
  $ProviderElement<AppBootstrap> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppBootstrap create(Ref ref) {
    return appBootstrap(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppBootstrap value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppBootstrap>(value),
    );
  }
}

String _$appBootstrapHash() => r'317a06aed65cd78b65a297533133849944c6e056';
