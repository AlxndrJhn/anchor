import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/features/auth/data/remote/auth_service.dart';
import 'package:anchor/features/auth/domain/auth_failure.dart';
import 'package:anchor/features/auth/domain/oidc_config.dart';
import 'package:anchor/features/auth/presentation/oidc_config_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeServer implements HttpClientAdapter {
  bool isUp = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!isUp) throw const SocketException('Network is unreachable');
    return ResponseBody.fromString(
      jsonEncode({'enabled': true, 'providerName': 'Pocket ID'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('the sign-in options are asked for again once back online', () async {
    final server = _FakeServer();
    final connection = StreamController<List<ConnectivityResult>>();
    addTearDown(connection.close);
    final container = ProviderContainer(
      overrides: [
        serverUrlProvider.overrideWithValue('https://anchor.test'),
        authServiceProvider.overrideWithValue(
          AuthService(
            Dio(BaseOptions(baseUrl: 'https://anchor.test'))
              ..httpClientAdapter = server,
          ),
        ),
        connectivityStreamProvider.overrideWith((ref) => connection.stream),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    Future<AsyncValue<OidcConfig>> settled() async {
      await pumpEventQueue();
      return container.read(oidcConfigProvider);
    }

    container.listen(oidcConfigProvider, (_, _) {});
    connection.add([ConnectivityResult.none]);
    expect((await settled()).error, isA<UnreachableFailure>());

    server.isUp = true;
    connection.add([ConnectivityResult.wifi]);
    final config = (await settled()).requireValue;
    expect(config.enabled, isTrue);
    expect(config.providerName, 'Pocket ID');
  });
}
