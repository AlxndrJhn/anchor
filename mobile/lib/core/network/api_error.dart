import 'dart:io';

import 'package:dio/dio.dart';

import 'anchor_protocol.dart';

sealed class ApiError {
  const ApiError({this.cause});

  final Object? cause;

  factory ApiError.from(DioException exception) {
    final cause = exception.error;
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutApiError(cause: cause);
      case DioExceptionType.connectionError:
        return OfflineApiError(cause: cause);
      case DioExceptionType.badCertificate:
        return CertificateApiError(cause: cause);
      case DioExceptionType.cancel:
        return CancelledApiError(cause: cause);
      case DioExceptionType.unknown:
        if (cause is HandshakeException &&
            (cause.osError?.message.contains('CERTIFICATE_VERIFY_FAILED') ??
                false)) {
          return CertificateApiError(cause: cause);
        }
        final text = '$cause';
        if (text.contains('SocketException') ||
            text.contains('Network is unreachable')) {
          return OfflineApiError(cause: cause);
        }
        return ServerApiError(cause: cause);
      case DioExceptionType.badResponse:
        break;
    }

    final status = exception.response?.statusCode;
    final message = _serverMessageOf(exception.response?.data);
    return switch (status) {
      400 when message is List => ValidationApiError([
        for (final item in message) '$item',
      ]),
      400 => ValidationApiError([if (message is String) message]),
      401 => UnauthorizedApiError(cause: cause),
      403 => ForbiddenApiError(cause: cause),
      404 => NotFoundApiError(cause: cause),
      upgradeRequiredStatus => UpgradeRequiredApiError(cause: cause),
      _ => ServerApiError(statusCode: status, cause: cause),
    };
  }

  @override
  String toString() => cause == null ? '$runtimeType' : '$runtimeType: $cause';
}

class OfflineApiError extends ApiError {
  const OfflineApiError({super.cause});
}

class TimeoutApiError extends ApiError {
  const TimeoutApiError({super.cause});
}

class CertificateApiError extends ApiError {
  const CertificateApiError({super.cause});
}

class CancelledApiError extends ApiError {
  const CancelledApiError({super.cause});
}

class UnauthorizedApiError extends ApiError {
  const UnauthorizedApiError({super.cause});
}

class ForbiddenApiError extends ApiError {
  const ForbiddenApiError({super.cause});
}

class NotFoundApiError extends ApiError {
  const NotFoundApiError({super.cause});
}

class UpgradeRequiredApiError extends ApiError {
  const UpgradeRequiredApiError({super.cause});
}

class ValidationApiError extends ApiError {
  const ValidationApiError(this.messages, {super.cause});

  final List<String> messages;
}

class ServerApiError extends ApiError {
  const ServerApiError({this.statusCode, super.cause});

  final int? statusCode;
}

extension DioExceptionApiError on DioException {
  ApiError get apiError => switch (error) {
    final ApiError attached => attached,
    _ => ApiError.from(this),
  };
}

Object? _serverMessageOf(Object? data) => data is Map ? data['message'] : null;
