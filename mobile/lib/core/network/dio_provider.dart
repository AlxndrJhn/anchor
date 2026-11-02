import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logging/logging_interceptor.dart';
import '../session/session_expired_provider.dart';
import '../storage/secure_storage_provider.dart';
import 'anchor_protocol.dart';
import 'api_error.dart';
import 'auth_interceptor.dart';
import 'server_config_provider.dart';

part 'dio_provider.g.dart';

IOHttpClientAdapter createSelfSignedCertAdapter(String serverUrl) {
  final uri = Uri.tryParse(serverUrl);
  final allowedHost = uri?.host;

  return IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
            return host == allowedHost;
          };
      return client;
    },
  );
}

/// [headers] go out with every request, besides the app's own.
Dio createServerDio(
  String? serverUrl, {
  required bool allowSelfSigned,
  Map<String, String> headers = const {},
}) {
  final hasServer = serverUrl != null && serverUrl.isNotEmpty;
  final dio = Dio(
    BaseOptions(
      baseUrl: hasServer ? serverUrl : '',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Names this app in Settings' list of signed-in devices.
        'User-Agent': 'AnchorPlus/${Platform.operatingSystem}',
        ...headers,
      },
    ),
  );
  if (allowSelfSigned && hasServer) {
    dio.httpClientAdapter = createSelfSignedCertAdapter(serverUrl);
  }
  return dio;
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) => createApiDio(
  ref.watch(serverUrlProvider),
  allowSelfSigned: ref.watch(allowSelfSignedCertProvider).value ?? false,
  headers: ref.watch(serverHeadersProvider),
  storage: ref.watch(secureStorageProvider),
  session: ref.read(sessionExpiredProvider.notifier),
);

/// Signs its requests in, refreshing the sign-in when the server refuses it.
Dio createApiDio(
  String? serverUrl, {
  required bool allowSelfSigned,
  Map<String, String> headers = const {},
  required FlutterSecureStorage storage,
  required SessionExpired session,
}) {
  final dio = createServerDio(
    serverUrl,
    allowSelfSigned: allowSelfSigned,
    headers: headers,
  );
  dio.options.headers[anchorProtocolHeader] = '$anchorProtocol';

  // Refresh requests must skip the interceptors.
  final refreshDio = createServerDio(
    serverUrl,
    allowSelfSigned: allowSelfSigned,
    headers: headers,
  );

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      storage: storage,
      session: session,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) =>
          handler.next(error.copyWith(error: error.apiError)),
    ),
  );

  dio.interceptors.add(LoggingInterceptor());

  return dio;
}
