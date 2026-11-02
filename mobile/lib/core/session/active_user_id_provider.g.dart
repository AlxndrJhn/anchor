// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_user_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ActiveUserId)
final activeUserIdProvider = ActiveUserIdProvider._();

final class ActiveUserIdProvider
    extends $NotifierProvider<ActiveUserId, String?> {
  ActiveUserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeUserIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeUserIdHash();

  @$internal
  @override
  ActiveUserId create() => ActiveUserId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeUserIdHash() => r'470bedac248ff06a19e7e5bc24081cdcd9cd9c30';

abstract class _$ActiveUserId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the open notes stay on this device, with no server to sync with.

@ProviderFor(isLocalOnly)
final isLocalOnlyProvider = IsLocalOnlyProvider._();

/// Whether the open notes stay on this device, with no server to sync with.

final class IsLocalOnlyProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the open notes stay on this device, with no server to sync with.
  IsLocalOnlyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isLocalOnlyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isLocalOnlyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isLocalOnly(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isLocalOnlyHash() => r'5aded49561c5450d133493d3d73f8aa24e3de5cf';
