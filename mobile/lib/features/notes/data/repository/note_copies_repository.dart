import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_provider.dart';

part 'note_copies_repository.g.dart';

@Riverpod(keepAlive: true)
NoteCopiesRepository noteCopiesRepository(Ref ref) =>
    NoteCopiesRepository(ref.watch(dioProvider));

/// "Make a copy" happens on the server, which also copies the attachments.
class NoteCopiesRepository {
  NoteCopiesRepository(this._dio);

  final Dio _dio;

  /// The copy's id: a note of the person's own with the same title, text,
  /// colour, their tags and copies of the attachments.
  Future<String> copy(String noteId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/notes/$noteId/copy',
    );
    final id = response.data?['id'];
    if (id is! String) throw StateError('The server sent no copy');
    return id;
  }
}
