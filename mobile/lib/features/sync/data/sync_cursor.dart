import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../notes/domain/note_attachment.dart';
import 'sync_response.dart';

class SyncCursor {
  SyncCursor(this._db);

  final AppDatabase _db;

  static Stream<bool> watchHasDownloaded(AppDatabase db) => db
      .select(db.syncState)
      .watchSingleOrNull()
      .map((row) => row != null && row.cursor != null && !row.isSweeping);

  /// With no cursor, first lists everything held here for the sweep.
  Future<String?> prepare() async {
    final state = await _state();
    if (state.cursor == null && !state.isSweeping) {
      await _beginSweep();
    }
    return state.cursor;
  }

  Future<void> reset() async {
    await _db.transaction(() async {
      await _db.delete(_db.syncSweep).go();
      await _db
          .update(_db.syncState)
          .write(
            const SyncStateCompanion(
              cursor: Value(null),
              isSweeping: Value(false),
            ),
          );
    });
  }

  Future<void> save(String? cursor) async {
    await _db
        .update(_db.syncState)
        .write(SyncStateCompanion(cursor: Value(cursor)));
  }

  Future<bool> isSweeping() async => (await _state()).isSweeping;

  /// What the server has not sent back since the full download started.
  Future<List<SyncSweepData>> leftovers() => _db.select(_db.syncSweep).get();

  Future<void> removeFromSweep(
    SyncEntityType entityType,
    String entityId,
  ) async {
    await (_db.delete(_db.syncSweep)..where(
          (tbl) =>
              tbl.entityType.equals(entityType.name) &
              tbl.entityId.equals(entityId),
        ))
        .go();
  }

  Future<void> endSweep() async {
    await _db.delete(_db.syncSweep).go();
    await _db
        .update(_db.syncState)
        .write(const SyncStateCompanion(isSweeping: Value(false)));
  }

  Future<SyncStateData> _state() async {
    final row = await _db.select(_db.syncState).getSingleOrNull();
    if (row != null) return row;
    await _db.into(_db.syncState).insert(SyncStateCompanion.insert());
    return _db.select(_db.syncState).getSingle();
  }

  Future<void> _beginSweep() async {
    await _db.transaction(() async {
      await _db.delete(_db.syncSweep).go();

      final noteIds =
          await (_db.selectOnly(_db.notes)
                ..addColumns([_db.notes.id])
                ..where(_db.notes.isSynced.equals(true)))
              .map((row) => row.read(_db.notes.id)!)
              .get();
      final tagIds =
          await (_db.selectOnly(_db.tags)
                ..addColumns([_db.tags.id])
                ..where(_db.tags.isSynced.equals(true)))
              .map((row) => row.read(_db.tags.id)!)
              .get();
      final attachedNoteIds =
          await (_db.selectOnly(_db.noteAttachments, distinct: true)
                ..addColumns([_db.noteAttachments.noteId])
                ..where(
                  _db.noteAttachments.syncStatus.equals(
                    AttachmentSyncStatus.synced.dbValue,
                  ),
                ))
              .map((row) => row.read(_db.noteAttachments.noteId)!)
              .get();

      await _db.batch((batch) {
        batch.insertAll(_db.syncSweep, [
          for (final id in noteIds) _sweepRow(SyncEntityType.note, id),
          for (final id in tagIds) _sweepRow(SyncEntityType.tag, id),
          for (final id in attachedNoteIds)
            _sweepRow(SyncEntityType.attachments, id),
        ], mode: InsertMode.insertOrReplace);
      });

      await _db
          .update(_db.syncState)
          .write(const SyncStateCompanion(isSweeping: Value(true)));
    });
  }

  SyncSweepCompanion _sweepRow(SyncEntityType entityType, String entityId) =>
      SyncSweepCompanion.insert(
        entityType: entityType.name,
        entityId: entityId,
      );
}
