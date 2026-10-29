import 'dart:io';

import 'package:anchor/core/network/api_error.dart';
import 'package:anchor/core/network/api_error_text.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  final options = RequestOptions(path: '/api/notes');

  DioException failure({
    DioExceptionType type = DioExceptionType.badResponse,
    int? status,
    Object? data,
    Object? error,
  }) => DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: data),
  );

  test('no connection reads as offline', () {
    expect(
      failure(type: DioExceptionType.connectionError).apiError,
      isA<OfflineApiError>(),
    );
    expect(
      failure(
        type: DioExceptionType.unknown,
        error: const SocketException('Connection refused'),
      ).apiError,
      isA<OfflineApiError>(),
    );
  });

  test(
    'a certificate the phone doesn’t trust reads as a certificate error',
    () {
      expect(
        failure(
          type: DioExceptionType.unknown,
          error: const HandshakeException(
            'Handshake error in client',
            OSError('CERTIFICATE_VERIFY_FAILED: self signed certificate', 1),
          ),
        ).apiError,
        isA<CertificateApiError>(),
      );
      expect(
        failure(
          type: DioExceptionType.unknown,
          error: const HandshakeException(
            'Handshake error in client',
            OSError('WRONG_VERSION_NUMBER', 1),
          ),
        ).apiError,
        isNot(isA<CertificateApiError>()),
      );
    },
  );

  test('every kind of timeout reads as a timeout', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      expect(failure(type: type).apiError, isA<TimeoutApiError>());
    }
  });

  test('status codes map to their kind', () {
    expect(failure(status: 401).apiError, isA<UnauthorizedApiError>());
    expect(failure(status: 403).apiError, isA<ForbiddenApiError>());
    expect(failure(status: 404).apiError, isA<NotFoundApiError>());
    expect(failure(status: 426).apiError, isA<UpgradeRequiredApiError>());
  });

  test('a validation answer keeps what the server said and asks to check '
      'the input', () {
    final error = failure(
      status: 400,
      data: {
        'message': ['email must be an email', 'password is too short'],
      },
    ).apiError;

    expect(error, isA<ValidationApiError>());
    expect((error as ValidationApiError).messages, [
      'email must be an email',
      'password is too short',
    ]);
    expect(apiErrorText(error, _english), 'Check the information you entered.');
  });

  test('a server failure never shows the server’s own English text', () {
    final crashed = failure(status: 500, data: {'message': 'Database is down'});
    final gateway = failure(status: 502, data: 'Bad gateway');
    final conflict = failure(status: 409, data: {'message': 'Conflict'});

    expect(
      apiErrorText(crashed, _english),
      'The server ran into a problem. Try again later.',
    );
    expect((gateway.apiError as ServerApiError).statusCode, 502);
    expect(
      apiErrorText(gateway, _english),
      'The server ran into a problem. Try again later.',
    );
    expect(
      apiErrorText(conflict, _english),
      'Something went wrong. Try again.',
    );
  });

  test('an error put on the exception is the one read back', () {
    const attached = OfflineApiError();
    final exception = failure(status: 500).copyWith(error: attached);

    expect(exception.apiError, same(attached));
  });

  test('anything that is not a request failure gets the general message', () {
    expect(
      apiErrorText(StateError('boom'), _english),
      'Something went wrong. Try again.',
    );
    expect(
      apiErrorText(const OfflineApiError(), _english),
      'No internet connection.',
    );
  });
}
