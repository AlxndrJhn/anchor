// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_updater.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateSource)
final updateSourceProvider = UpdateSourceProvider._();

final class UpdateSourceProvider
    extends $FunctionalProvider<UpdateSource, UpdateSource, UpdateSource>
    with $Provider<UpdateSource> {
  UpdateSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateSourceHash();

  @$internal
  @override
  $ProviderElement<UpdateSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateSource create(Ref ref) {
    return updateSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateSource>(value),
    );
  }
}

String _$updateSourceHash() => r'85c799a70f86ac0d2f12a30a1711297c2f7e8fcf';

/// This build's number in the fork's releases.

@ProviderFor(installedBuildNumber)
final installedBuildNumberProvider = InstalledBuildNumberProvider._();

/// This build's number in the fork's releases.

final class InstalledBuildNumberProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// This build's number in the fork's releases.
  InstalledBuildNumberProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedBuildNumberProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedBuildNumberHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return installedBuildNumber(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$installedBuildNumberHash() =>
    r'79a915a614372430471f40ce5a9823647e32d03e';

/// Finds, downloads and installs newer releases of the fork from GitHub.

@ProviderFor(UpdateController)
final updateControllerProvider = UpdateControllerProvider._();

/// Finds, downloads and installs newer releases of the fork from GitHub.
final class UpdateControllerProvider
    extends $NotifierProvider<UpdateController, UpdateState> {
  /// Finds, downloads and installs newer releases of the fork from GitHub.
  UpdateControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateControllerHash();

  @$internal
  @override
  UpdateController create() => UpdateController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateState>(value),
    );
  }
}

String _$updateControllerHash() => r'1ff0031eefa9a1125e88f579a8999415e965352c';

/// Finds, downloads and installs newer releases of the fork from GitHub.

abstract class _$UpdateController extends $Notifier<UpdateState> {
  UpdateState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateState, UpdateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateState, UpdateState>,
              UpdateState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
