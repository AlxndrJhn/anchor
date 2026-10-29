import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/ids.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_tags.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/sync_requester.dart';
import '../../domain/note_attachment.dart';

part 'note_attachments_repository.g.dart';

@Riverpod(keepAlive: true)
NoteAttachmentsRepository noteAttachmentsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);

  return NoteAttachmentsRepository(db, dio);
}

class NoteAttachmentsRepository {
  final AppDatabase _db;
  final Dio _dio;

  final Map<String, Future<String>> _activeDownloads = {};

  final Map<String, String> _serverIdByLocalId = {};

  String currentIdOf(String attachmentId) =>
      _serverIdByLocalId[attachmentId] ?? attachmentId;

  NoteAttachmentsRepository(this._db, this._dio);

  Stream<List<NoteAttachment>> watchAttachments(String noteId) {
    return (_db.select(_db.noteAttachments)
          ..where(
            (tbl) =>
                tbl.noteId.equals(noteId) &
                tbl.syncStatus
                    .equals(AttachmentSyncStatus.pendingDelete.dbValue)
                    .not(),
          )
          ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.position)]))
        .watch()
        .map((rows) => rows.map(_mapToDomain).toList());
  }

  /// Replaces a note's attachment list with the server's, leaving anything
  /// pending alone. Returns cached files the caller should delete once saved.
  Future<List<String>> applyServerAttachments(
    String noteId,
    List<NoteAttachment> items,
  ) async {
    final orphanedPaths = <String>[];

    await _db.transaction(() async {
      final serverIds = items.map((a) => a.id).toSet();
      final localRows = await (_db.select(
        _db.noteAttachments,
      )..where((tbl) => tbl.noteId.equals(noteId))).get();

      for (final row in localRows) {
        if (row.syncStatus != AttachmentSyncStatus.synced.dbValue) {
          continue;
        }
        if (serverIds.contains(row.serverAttachmentId ?? row.id)) {
          continue;
        }
        if (row.localPath != null) {
          orphanedPaths.add(row.localPath!);
        }
        await (_db.delete(
          _db.noteAttachments,
        )..where((tbl) => tbl.id.equals(row.id))).go();
      }

      for (final attachment in items) {
        final existing =
            await (_db.select(_db.noteAttachments)
                  ..where(
                    (tbl) =>
                        tbl.id.equals(attachment.id) |
                        tbl.serverAttachmentId.equals(attachment.id),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (existing?.syncStatus ==
            AttachmentSyncStatus.pendingDelete.dbValue) {
          continue;
        }

        await _db
            .into(_db.noteAttachments)
            .insertOnConflictUpdate(
              NoteAttachmentsCompanion.insert(
                id: attachment.id,
                noteId: noteId,
                type: attachment.type.name,
                originalFilename: attachment.originalFilename,
                mimeType: attachment.mimeType,
                fileSize: attachment.fileSize,
                position: drift.Value(attachment.position),
                localPath: drift.Value(existing?.localPath),
                syncStatus: drift.Value(AttachmentSyncStatus.synced.dbValue),
                serverAttachmentId: drift.Value(attachment.id),
                uploadedByUserId: drift.Value(attachment.uploadedByUserId),
              ),
            );
      }
    });

    return orphanedPaths;
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final filePath in paths) {
      try {
        await File(filePath).delete();
      } catch (e, stack) {
        AppLogger.instance.error(
          LogTags.attachments,
          'Failed to delete local file $filePath',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  Future<String> downloadAttachment(
    String noteId,
    String attachmentId,
    String filename,
  ) async {
    final attachmentDir = _noteDir(
      await getApplicationCacheDirectory(),
      noteId,
    );
    if (!attachmentDir.existsSync()) {
      attachmentDir.createSync(recursive: true);
    }

    final filePath = path.join(attachmentDir.path, '$attachmentId-$filename');
    final file = File(filePath);

    if (file.existsSync() && file.lengthSync() > 0) {
      return filePath;
    }
    if (file.existsSync()) {
      file.deleteSync();
    }

    final existsLocally =
        await (_db.selectOnly(_db.noteAttachments)
              ..addColumns([_db.noteAttachments.id])
              ..where(
                _db.noteAttachments.id.equals(attachmentId) |
                    _db.noteAttachments.serverAttachmentId.equals(attachmentId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existsLocally == null) {
      AppLogger.instance.debug(
        LogTags.attachments,
        'Skip download for $attachmentId (noteId=$noteId): not in local DB, '
        'so the attachment was likely deleted',
      );
      throw StateError('Attachment $attachmentId no longer exists locally');
    }

    if (_activeDownloads.containsKey(attachmentId)) {
      return _activeDownloads[attachmentId]!;
    }

    final future = _doDownload(noteId, attachmentId, filePath);
    _activeDownloads[attachmentId] = future;
    try {
      return await future;
    } finally {
      _activeDownloads.remove(attachmentId);
    }
  }

  Future<String> _doDownload(
    String noteId,
    String attachmentId,
    String filePath,
  ) async {
    final tmpPath = '$filePath.tmp';
    try {
      await _dio.download(
        '/api/notes/$noteId/attachments/$attachmentId',
        tmpPath,
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );

      final tmpFile = File(tmpPath);
      if (!tmpFile.existsSync() || tmpFile.lengthSync() == 0) {
        throw Exception('Download produced empty file');
      }

      await tmpFile.rename(filePath);
    } catch (e) {
      try {
        File(tmpPath).deleteSync();
      } catch (_) {}
      rethrow;
    }

    await (_db.update(_db.noteAttachments)..where(
          (tbl) =>
              tbl.noteId.equals(noteId) &
              (tbl.id.equals(attachmentId) |
                  tbl.serverAttachmentId.equals(attachmentId)),
        ))
        .write(NoteAttachmentsCompanion(localPath: drift.Value(filePath)));

    return filePath;
  }

  Future<void> retryUpload(String id) async {
    await (_db.update(_db.noteAttachments)..where(
          (tbl) =>
              tbl.id.equals(id) &
              tbl.syncStatus.equals(AttachmentSyncStatus.uploadFailed.dbValue),
        ))
        .write(
          NoteAttachmentsCompanion(
            syncStatus: drift.Value(AttachmentSyncStatus.pendingUpload.dbValue),
          ),
        );
    scheduleAppSync(trigger: 'AttachmentsRepo.retryUpload');
  }

  Future<void> deleteAttachment(String noteId, String id) async {
    final attachmentId = currentIdOf(id);
    final rows =
        await (_db.select(_db.noteAttachments)..where(
              (tbl) =>
                  tbl.noteId.equals(noteId) &
                  tbl.syncStatus
                      .equals(AttachmentSyncStatus.pendingDelete.dbValue)
                      .not() &
                  (tbl.id.equals(attachmentId) |
                      tbl.serverAttachmentId.equals(attachmentId)),
            ))
            .get();

    if (rows.isEmpty) return;

    final row = rows.first;
    if (row.syncStatus == AttachmentSyncStatus.pendingUpload.dbValue ||
        row.syncStatus == AttachmentSyncStatus.uploadFailed.dbValue) {
      await deleteFiles([?row.localPath]);
      await (_db.delete(
        _db.noteAttachments,
      )..where((tbl) => tbl.id.equals(row.id))).go();
    } else {
      await (_db.update(
        _db.noteAttachments,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        NoteAttachmentsCompanion(
          syncStatus: drift.Value(AttachmentSyncStatus.pendingDelete.dbValue),
        ),
      );
    }

    await _touchNote(noteId);
    scheduleAppSync(trigger: 'AttachmentsRepo.deleteAttachment');
  }

  Future<void> _touchNote(String noteId) async {
    await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(noteId))).write(
      NotesCompanion(updatedAt: drift.Value(DateTime.now().toUtc())),
    );
  }

  /// Throws [AttachmentTooBigException].
  Future<void> checkSize(String filePath) async {
    if (await File(filePath).length() > maxAttachmentBytes) {
      throw const AttachmentTooBigException();
    }
  }

  Future<String> addAttachment(
    String noteId,
    String sourceFilePath,
    String mimeType,
    String originalFilename,
  ) async {
    await checkSize(sourceFilePath);
    final localId = newId();
    final safeName = path.basename(originalFilename);
    final attachmentDir = _noteDir(
      await getApplicationDocumentsDirectory(),
      noteId,
    );
    final persistentPath = path.join(attachmentDir.path, '$localId-$safeName');

    if (!attachmentDir.existsSync()) {
      attachmentDir.createSync(recursive: true);
    }
    await File(sourceFilePath).copy(persistentPath);

    final type = AttachmentType.fromMimeType(mimeType);

    try {
      await _db.transaction(() async {
        final tbl = _db.noteAttachments;
        await (_db.update(tbl)..where((t) => t.noteId.equals(noteId))).write(
          NoteAttachmentsCompanion.custom(
            position: tbl.position + const drift.Constant(1),
          ),
        );

        await _db
            .into(_db.noteAttachments)
            .insert(
              NoteAttachmentsCompanion.insert(
                id: localId,
                noteId: noteId,
                type: type.name,
                originalFilename: originalFilename,
                mimeType: mimeType,
                fileSize: File(persistentPath).lengthSync(),
                position: const drift.Value(0),
                localPath: drift.Value(persistentPath),
                syncStatus: drift.Value(
                  AttachmentSyncStatus.pendingUpload.dbValue,
                ),
              ),
            );

        await _touchNote(noteId);
      });
    } catch (e) {
      await deleteFiles([persistentPath]);
      rethrow;
    }

    scheduleAppSync(trigger: 'AttachmentsRepo.addAttachment');
    return localId;
  }

  Future<void> sync() async {
    final cycleStart = DateTime.now();
    final failedAttachmentIds = <String>[];
    int uploaded = 0;
    int deleted = 0;
    int skipped = 0;

    final pendingUpload =
        await (_db.select(_db.noteAttachments)..where(
              (tbl) => tbl.syncStatus.equals(
                AttachmentSyncStatus.pendingUpload.dbValue,
              ),
            ))
            .get();

    final pendingDelete =
        await (_db.select(_db.noteAttachments)..where(
              (tbl) => tbl.syncStatus.equals(
                AttachmentSyncStatus.pendingDelete.dbValue,
              ),
            ))
            .get();

    if (pendingUpload.isEmpty && pendingDelete.isEmpty) {
      return;
    }

    AppLogger.instance.info(
      LogTags.attachments,
      'Attachments sync start: pendingUploads=${pendingUpload.length} '
      'pendingDeletes=${pendingDelete.length}',
    );

    for (final row in pendingUpload) {
      if (row.localPath == null) {
        AppLogger.instance.warn(
          LogTags.attachments,
          'Skip upload ${row.id}: missing localPath (noteId=${row.noteId})',
        );
        skipped++;
        continue;
      }
      try {
        final attachment = await _uploadToServer(
          row.noteId,
          row.localPath!,
          row.mimeType,
          row.originalFilename,
        );

        String? cachedPath;
        try {
          final cacheAttachDir = _noteDir(
            await getApplicationCacheDirectory(),
            attachment.noteId,
          );
          if (!cacheAttachDir.existsSync()) {
            cacheAttachDir.createSync(recursive: true);
          }
          cachedPath = path.join(
            cacheAttachDir.path,
            '${attachment.id}-${attachment.originalFilename}',
          );
          await File(row.localPath!).rename(cachedPath);
        } catch (e, stack) {
          // Rename can fail across filesystems.
          AppLogger.instance.warn(
            LogTags.attachments,
            'Failed to move upload to cache',
            error: e,
            stackTrace: stack,
          );
          cachedPath = null;
          try {
            await File(row.localPath!).delete();
          } catch (_) {}
        }

        _serverIdByLocalId[row.id] = attachment.id;
        final isDeletedMeanwhile = await _db.transaction(() async {
          final isGone =
              await (_db.select(
                _db.noteAttachments,
              )..where((tbl) => tbl.id.equals(row.id))).getSingleOrNull() ==
              null;
          await _db
              .into(_db.noteAttachments)
              .insertOnConflictUpdate(
                NoteAttachmentsCompanion.insert(
                  id: attachment.id,
                  noteId: attachment.noteId,
                  type: attachment.type.name,
                  originalFilename: attachment.originalFilename,
                  mimeType: attachment.mimeType,
                  fileSize: attachment.fileSize,
                  position: drift.Value(attachment.position),
                  localPath: drift.Value(cachedPath),
                  syncStatus: drift.Value(
                    isGone
                        ? AttachmentSyncStatus.pendingDelete.dbValue
                        : AttachmentSyncStatus.synced.dbValue,
                  ),
                  serverAttachmentId: drift.Value(attachment.id),
                  uploadedByUserId: drift.Value(attachment.uploadedByUserId),
                ),
              );

          await (_db.delete(
            _db.noteAttachments,
          )..where((tbl) => tbl.id.equals(row.id))).go();
          return isGone;
        });
        if (isDeletedMeanwhile) {
          scheduleAppSync(trigger: 'AttachmentsRepo.deletedWhileUploading');
        }
        uploaded++;
        AppLogger.instance.info(
          LogTags.attachments,
          'Uploaded attachment ${attachment.id} for note ${attachment.noteId} '
          '(${attachment.fileSize}B, ${attachment.mimeType})',
        );
      } catch (e, stack) {
        AppLogger.instance.error(
          LogTags.attachments,
          'Attachment upload failed for ${row.id} (noteId=${row.noteId})',
          error: e,
          stackTrace: stack,
        );
        if (_isRefused(e)) {
          await (_db.update(
            _db.noteAttachments,
          )..where((tbl) => tbl.id.equals(row.id))).write(
            NoteAttachmentsCompanion(
              syncStatus: drift.Value(
                AttachmentSyncStatus.uploadFailed.dbValue,
              ),
            ),
          );
        } else {
          failedAttachmentIds.add(row.id);
        }
      }
    }

    for (final row in pendingDelete) {
      final serverId = row.serverAttachmentId ?? row.id;
      try {
        await _dio.delete('/api/notes/${row.noteId}/attachments/$serverId');
        await deleteFiles([?row.localPath]);
        await (_db.delete(
          _db.noteAttachments,
        )..where((tbl) => tbl.id.equals(row.id))).go();
        deleted++;
        AppLogger.instance.info(
          LogTags.attachments,
          'Deleted attachment ${row.id} (serverId=$serverId noteId=${row.noteId})',
        );
      } catch (e, stack) {
        AppLogger.instance.error(
          LogTags.attachments,
          'Attachment delete failed for ${row.id} (noteId=${row.noteId})',
          error: e,
          stackTrace: stack,
        );
        failedAttachmentIds.add(row.id);
      }
    }

    AppLogger.instance.info(
      LogTags.attachments,
      'Attachments sync done in '
      '${DateTime.now().difference(cycleStart).inMilliseconds}ms: '
      'uploaded=$uploaded deleted=$deleted skipped=$skipped '
      'failed=${failedAttachmentIds.length}',
    );

    if (failedAttachmentIds.isNotEmpty) {
      throw Exception(
        'Attachment sync failed for ${failedAttachmentIds.length} attachment(s)',
      );
    }
  }

  Future<NoteAttachment> _uploadToServer(
    String noteId,
    String localFilePath,
    String mimeType,
    String originalFilename,
  ) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        localFilePath,
        filename: originalFilename,
        contentType: DioMediaType.parse(mimeType),
      ),
    });

    final response = await _dio.post(
      '/api/notes/$noteId/attachments',
      data: formData,
      options: Options(receiveTimeout: Duration.zero),
    );

    return NoteAttachment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteLocalFilesForNote(String noteId) async {
    for (final root in [
      await getApplicationDocumentsDirectory(),
      await getApplicationCacheDirectory(),
    ]) {
      final noteDir = _noteDir(root, noteId);
      if (noteDir.existsSync()) {
        try {
          await noteDir.delete(recursive: true);
        } catch (e, stack) {
          AppLogger.instance.error(
            LogTags.attachments,
            'Failed to delete attachment dir ${noteDir.path}',
            error: e,
            stackTrace: stack,
          );
        }
      }
    }
  }

  /// Runs inside the caller's transaction; returns the local files for the
  /// caller to delete once it commits.
  Future<List<String>> deleteRowsForNote(String noteId) async {
    final rows = await (_db.select(
      _db.noteAttachments,
    )..where((tbl) => tbl.noteId.equals(noteId))).get();
    await (_db.delete(
      _db.noteAttachments,
    )..where((tbl) => tbl.noteId.equals(noteId))).go();
    return [for (final row in rows) ?row.localPath];
  }

  Future<void> evictCache({int maxCacheBytes = 500 * 1024 * 1024}) async {
    final cacheDir = await getApplicationCacheDirectory();
    final attachmentsDir = Directory(path.join(cacheDir.path, 'attachments'));
    if (!attachmentsDir.existsSync()) return;

    final files = <File>[];
    int totalSize = 0;

    await for (final entity in attachmentsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        files.add(entity);
        totalSize += await entity.length();
      }
    }

    if (totalSize <= maxCacheBytes) return;

    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return aStat.accessed.compareTo(bStat.accessed);
    });

    for (final file in files) {
      if (totalSize <= maxCacheBytes) break;
      final size = await file.length();
      try {
        await file.delete();
        totalSize -= size;

        await (_db.update(
          _db.noteAttachments,
        )..where((tbl) => tbl.localPath.equals(file.path))).write(
          const NoteAttachmentsCompanion(localPath: drift.Value(null)),
        );

        AppLogger.instance.info(
          LogTags.attachments,
          'Evicted cached attachment: ${path.basename(file.path)} ($size bytes)',
        );
      } catch (e, stack) {
        AppLogger.instance.error(
          LogTags.attachments,
          'Failed to evict cached file ${file.path}',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  Directory _noteDir(Directory root, String noteId) =>
      Directory(path.join(root.path, 'attachments', noteId));

  NoteAttachment _mapToDomain(AttachmentRow row) {
    return NoteAttachment(
      id: row.serverAttachmentId ?? row.id,
      noteId: row.noteId,
      type: AttachmentType.fromString(row.type),
      originalFilename: row.originalFilename,
      mimeType: row.mimeType,
      fileSize: row.fileSize,
      position: row.position,
      uploadedByUserId: row.uploadedByUserId,
      localPath: row.localPath,
      isPendingUpload:
          AttachmentSyncStatus.fromString(row.syncStatus) ==
          AttachmentSyncStatus.pendingUpload,
      isUploadFailed:
          AttachmentSyncStatus.fromString(row.syncStatus) ==
          AttachmentSyncStatus.uploadFailed,
    );
  }
}

bool _isRefused(Object error) {
  if (error is! DioException || error.type != DioExceptionType.badResponse) {
    return false;
  }
  final status = error.response?.statusCode ?? 0;
  return status >= 400 &&
      status < 500 &&
      !const {401, 408, 429}.contains(status);
}
