import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_tags.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/note_share.dart';
import '../../domain/note_share_permission.dart';
import '../local/note_rows.dart';

part 'note_shares_repository.g.dart';

@Riverpod(keepAlive: true)
NoteSharesRepository noteSharesRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  return NoteSharesRepository(dio, db);
}

/// Request errors reach the caller; the Dio logger has already recorded them.
class NoteSharesRepository {
  final Dio _dio;
  final AppDatabase _db;

  NoteSharesRepository(this._dio, this._db);

  Future<NoteShare> shareNote(
    String noteId,
    String sharedWithUserId,
    NoteSharePermission permission,
  ) async {
    final response = await _dio.post(
      '/api/notes/$noteId/shares',
      data: {
        'sharedWithUserId': sharedWithUserId,
        'permission': permission.name,
      },
    );

    final share = NoteShare.fromJson(response.data as Map<String, dynamic>);

    await _updateLocalShareIds(noteId);

    return share;
  }

  Future<List<NoteShare>> getNoteShares(String noteId) async {
    final response = await _dio.get('/api/notes/$noteId/shares');

    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((e) => NoteShare.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NoteShare> updateNoteSharePermission(
    String noteId,
    String shareId,
    NoteSharePermission permission,
  ) async {
    final response = await _dio.patch(
      '/api/notes/$noteId/shares/$shareId',
      data: {'permission': permission.name},
    );

    return NoteShare.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> revokeShare(String noteId, String shareId) async {
    await _dio.delete('/api/notes/$noteId/shares/$shareId');

    await _updateLocalShareIds(noteId);
  }

  Future<void> _updateLocalShareIds(String noteId) async {
    try {
      final shares = await getNoteShares(noteId);
      final shareUserIds = shares.map((s) => s.sharedWithUser.id).toList();
      await _db.writeNote(
        noteId,
        NotesCompanion(shareIds: drift.Value(encodeShareIds(shareUserIds))),
      );
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.sharing,
        'Refreshing the shares on note $noteId failed',
        error: error,
      );
    }
  }
}
