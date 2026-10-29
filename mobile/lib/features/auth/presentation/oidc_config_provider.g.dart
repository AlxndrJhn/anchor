// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oidc_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(oidcConfig)
final oidcConfigProvider = OidcConfigProvider._();

final class OidcConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<OidcConfig>,
          OidcConfig,
          FutureOr<OidcConfig>
        >
    with $FutureModifier<OidcConfig>, $FutureProvider<OidcConfig> {
  OidcConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oidcConfigProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oidcConfigHash();

  @$internal
  @override
  $FutureProviderElement<OidcConfig> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OidcConfig> create(Ref ref) {
    return oidcConfig(ref);
  }
}

String _$oidcConfigHash() => r'c988473a8ee1694083788a5c2fd1f8ee6f015d48';
