import 'package:dio/dio.dart';

import 'sync_changes.dart';
import 'sync_response.dart';

export 'sync_changes.dart';
export 'sync_response.dart';

const String syncPath = '/api/sync';
const String syncEventsPath = '/api/sync/events';

class SyncApi {
  const SyncApi(this._dio);

  final Dio _dio;

  Future<SyncResponse> sync({
    String? cursor,
    List<SyncChange> changes = const [],
  }) async {
    final response = await _dio.post(
      syncPath,
      data: {
        'cursor': ?cursor,
        if (changes.isNotEmpty)
          'changes': [for (final change in changes) change.toJson()],
      },
    );
    return SyncResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
