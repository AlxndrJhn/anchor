import 'dart:math';

import 'package:dio/dio.dart';

import 'app_logger.dart';
import 'log_tags.dart';
import 'redaction.dart';

const _startTimeKey = 'app_logger_start_ts';
const _requestIdKey = 'app_logger_req_id';

const _boilerplateHeaders = <String>{'content-type', 'accept', 'authorization'};

/// Matched against [Uri.path] (no query string).
const _skipPaths = <String>{'/api/health', '/api/sync/events'};

final _random = Random();

String _newRequestId() {
  return _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
}

Map<String, dynamic> _nonDefaultHeaders(Map<String, dynamic> headers) {
  final out = <String, dynamic>{};
  for (final entry in headers.entries) {
    if (_boilerplateHeaders.contains(entry.key.toLowerCase())) continue;
    out[entry.key] = entry.value;
  }
  return out;
}

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_skipPaths.contains(options.uri.path)) {
      handler.next(options);
      return;
    }

    final requestId = _newRequestId();
    options.extra[_requestIdKey] = requestId;
    options.extra[_startTimeKey] = DateTime.now().millisecondsSinceEpoch;

    final body = options.data != null ? redactBody(options.data) : null;
    final headers = redactHeaders(_nonDefaultHeaders(options.headers));
    final redactedQuery = redactQuery(options.uri);
    final query = redactedQuery.isNotEmpty ? '?$redactedQuery' : '';
    final sizeSuffix = body != null ? ' (${body.length}B)' : '';

    final message = StringBuffer()
      ..write(
        '→[$requestId] ${options.method} ${options.uri.path}$query$sizeSuffix',
      );
    if (headers.isNotEmpty) {
      message.write('\nheaders: $headers');
    }
    if (body != null) {
      message.write('\nbody: $body');
    }
    AppLogger.instance.info(LogTags.dio, message.toString());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_skipPaths.contains(response.requestOptions.uri.path)) {
      handler.next(response);
      return;
    }
    final requestId = _requestIdOf(response.requestOptions);
    final duration = _duration(response.requestOptions);
    final body = response.data != null ? redactBody(response.data) : null;
    final sizeSuffix = body != null ? ', ${body.length}B' : '';

    final message = StringBuffer()
      ..write(
        '←[$requestId] ${response.requestOptions.method} '
        '${response.requestOptions.uri.path} '
        '${response.statusCode} (${duration}ms$sizeSuffix)',
      );
    if (body != null) {
      message.write('\nbody: $body');
    }
    AppLogger.instance.info(LogTags.dio, message.toString());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_skipPaths.contains(err.requestOptions.uri.path)) {
      handler.next(err);
      return;
    }
    final requestId = _requestIdOf(err.requestOptions);
    final duration = _duration(err.requestOptions);
    final status = err.response?.statusCode;
    final body = err.response?.data != null
        ? redactBody(err.response!.data)
        : null;

    final message = StringBuffer()
      ..write(
        '✗[$requestId] ${err.requestOptions.method} '
        '${err.requestOptions.uri.path} '
        '${status ?? err.type.name} (${duration}ms): ${err.message ?? ''}',
      );
    if (body != null) {
      message.write('\nresponse: $body');
    }
    AppLogger.instance.error(LogTags.dio, message.toString(), error: err.error);
    handler.next(err);
  }

  String _requestIdOf(RequestOptions options) {
    final value = options.extra[_requestIdKey];
    return value is String ? value : '------';
  }

  int _duration(RequestOptions options) {
    final start = options.extra[_startTimeKey];
    if (start is int) {
      return DateTime.now().millisecondsSinceEpoch - start;
    }
    return 0;
  }
}
