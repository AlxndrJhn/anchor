// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_unlock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(biometricUnlock)
final biometricUnlockProvider = BiometricUnlockProvider._();

final class BiometricUnlockProvider
    extends
        $FunctionalProvider<BiometricUnlock, BiometricUnlock, BiometricUnlock>
    with $Provider<BiometricUnlock> {
  BiometricUnlockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricUnlockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricUnlockHash();

  @$internal
  @override
  $ProviderElement<BiometricUnlock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BiometricUnlock create(Ref ref) {
    return biometricUnlock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiometricUnlock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiometricUnlock>(value),
    );
  }
}

String _$biometricUnlockHash() => r'24a57fb945ded5fc499ae75550d370bff3846799';
