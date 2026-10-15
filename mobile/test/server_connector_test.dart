import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchor/features/server/data/server_connector.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeServer implements HttpClientAdapter {
  _FakeServer(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Future<ServerCheck> _check(
  Future<ResponseBody> Function(RequestOptions options) respond,
) => ServerConnector(
  allowSelfSigned: false,
  dio: Dio()..httpClientAdapter = _FakeServer(respond),
).check('https://notes.example.com');

void main() {
  test('an Anchor server says what it speaks', () async {
    final check = await _check(
      (_) async => _json(200, {
        'app': 'anchor',
        'version': '0.17.0',
        'protocols': [3, 4],
      }),
    );

    expect(check, isA<ServerFound>());
    expect((check as ServerFound).info.protocols, [3, 4]);
  });

  test('asks the address it was given for its health', () async {
    late Uri asked;
    await _check((options) async {
      asked = options.uri;
      return _json(200, {'app': 'anchor'});
    });

    expect(asked.toString(), 'https://notes.example.com/api/health');
  });

  test('another app that answers is not an Anchor server', () async {
    expect(
      await _check((_) async => _json(200, {'app': 'nextcloud'})),
      isA<NotAnchorServer>(),
    );
    expect(
      await _check((_) async => _json(404, {'message': 'Not Found'})),
      isA<NotAnchorServer>(),
    );
  });

  test('a refused certificate and no answer are told apart', () async {
    expect(
      await _check(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.badCertificate,
        ),
      ),
      isA<UntrustedCertificate>(),
    );
    expect(
      await _check(
        (_) async => throw const HandshakeException(
          'Handshake error in client',
          OSError('CERTIFICATE_VERIFY_FAILED: self signed certificate', 1),
        ),
      ),
      isA<UntrustedCertificate>(),
    );
    expect(
      await _check(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'Connection refused',
        ),
      ),
      isA<ServerUnreachable>(),
    );
  });
}
