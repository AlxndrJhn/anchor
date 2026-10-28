import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_provider.dart';

part 'note_freeze_repository.g.dart';

@Riverpod(keepAlive: true)
NoteFreezeRepository noteFreezeRepository(Ref ref) =>
    NoteFreezeRepository(ref.watch(dioProvider));

/// Freezing is asked of the server straight away, never synced: a phone
/// that is behind can't unfreeze a note by mistake.
class NoteFreezeRepository {
  NoteFreezeRepository(this._dio);

  final Dio _dio;

  /// Only the notes' owner can; throws when the server can't be reached.
  Future<void> setFrozen(List<String> ids, {required bool isFrozen}) async {
    if (ids.length == 1) {
      await _dio.patch<void>(
        '/api/notes/${ids.single}/freeze',
        data: {'isFrozen': isFrozen},
      );
    } else {
      await _dio.post<void>(
        '/api/notes/bulk/freeze',
        data: {'noteIds': ids, 'isFrozen': isFrozen},
      );
    }
  }
}
