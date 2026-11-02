// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServerConfig)
final serverConfigProvider = ServerConfigProvider._();

final class ServerConfigProvider
    extends $AsyncNotifierProvider<ServerConfig, String?> {
  ServerConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverConfigHash();

  @$internal
  @override
  ServerConfig create() => ServerConfig();
}

String _$serverConfigHash() => r'9b3d428457be5e8eb3a9d688284353318bb9a84b';

abstract class _$ServerConfig extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(serverUrl)
final serverUrlProvider = ServerUrlProvider._();

final class ServerUrlProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  ServerUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverUrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverUrlHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return serverUrl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$serverUrlHash() => r'd4257305921fa0bbecbe8621dc4adc024d756f1c';

@ProviderFor(AllowSelfSignedCert)
final allowSelfSignedCertProvider = AllowSelfSignedCertProvider._();

final class AllowSelfSignedCertProvider
    extends $AsyncNotifierProvider<AllowSelfSignedCert, bool> {
  AllowSelfSignedCertProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allowSelfSignedCertProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allowSelfSignedCertHash();

  @$internal
  @override
  AllowSelfSignedCert create() => AllowSelfSignedCert();
}

String _$allowSelfSignedCertHash() =>
    r'e4e50e0b0f52511fec19be9a829aa94249abce7d';

abstract class _$AllowSelfSignedCert extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The extra headers saved with a server, if any.

@ProviderFor(SavedServerHeaders)
final savedServerHeadersProvider = SavedServerHeadersProvider._();

/// The extra headers saved with a server, if any.
final class SavedServerHeadersProvider
    extends $AsyncNotifierProvider<SavedServerHeaders, ServerHeaders?> {
  /// The extra headers saved with a server, if any.
  SavedServerHeadersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedServerHeadersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedServerHeadersHash();

  @$internal
  @override
  SavedServerHeaders create() => SavedServerHeaders();
}

String _$savedServerHeadersHash() =>
    r'532560d482e29011874f598ce9530244007145c2';

/// The extra headers saved with a server, if any.

abstract class _$SavedServerHeaders extends $AsyncNotifier<ServerHeaders?> {
  FutureOr<ServerHeaders?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ServerHeaders?>, ServerHeaders?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ServerHeaders?>, ServerHeaders?>,
              AsyncValue<ServerHeaders?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The extra headers to send to the server in use.

@ProviderFor(serverHeaders)
final serverHeadersProvider = ServerHeadersProvider._();

/// The extra headers to send to the server in use.

final class ServerHeadersProvider
    extends
        $FunctionalProvider<
          Map<String, String>,
          Map<String, String>,
          Map<String, String>
        >
    with $Provider<Map<String, String>> {
  /// The extra headers to send to the server in use.
  ServerHeadersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverHeadersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverHeadersHash();

  @$internal
  @override
  $ProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, String> create(Ref ref) {
    return serverHeaders(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$serverHeadersHash() => r'08f899bf284b3ad3830fd505d05f3e0169a7e252';
