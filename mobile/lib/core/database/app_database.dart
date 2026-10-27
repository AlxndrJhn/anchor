import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/notes/data/local/notes_table.dart';
import '../../features/notes/data/local/attachments_table.dart';
import '../../features/notes/data/local/note_history_state_table.dart';
import '../../features/notes/data/local/note_revisions_table.dart';
import '../../features/sync/data/local/sync_tables.dart';
import '../../features/tags/data/local/tags_table.dart';
import '../providers/active_user_id_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Notes,
    Tags,
    NoteTags,
    NoteAttachments,
    NoteRevisions,
    NoteHistoryState,
    SyncState,
    SyncSweep,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(String userId) : super(_openConnection(userId));

  // For tests: pass e.g. NativeDatabase.memory().
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 4) {
        await m.createTable(tags);
        await m.createTable(noteTags);
      }
      if (from < 5) {
        await m.renameColumn(notes, 'color', notes.background);
      }
      if (from < 6) {
        // Add sharing columns
        await m.addColumn(notes, notes.permission);
        await m.addColumn(notes, notes.shareIds);
        await m.addColumn(notes, notes.sharedById);
        await m.addColumn(notes, notes.sharedByName);
        await m.addColumn(notes, notes.sharedByEmail);
        await m.addColumn(notes, notes.sharedByProfileImage);
      }
      if (from < 7) {
        await m.createTable(noteAttachments);
      }
      if (from < 8) {
        await m.addColumn(notes, notes.version);
        await m.addColumn(notes, notes.localRev);
        await m.addColumn(notes, notes.isPinSynced);
        await m.addColumn(tags, tags.version);
        await m.addColumn(tags, tags.localRev);
        await m.createTable(syncState);
        await m.createTable(syncSweep);

        await (update(notes)..where(
              (tbl) => tbl.isSynced.equals(false) & tbl.isPinned.equals(true),
            ))
            .write(const NotesCompanion(isPinSynced: Value(false)));
      }
      if (from < 9) {
        await m.createTable(noteRevisions);
        await m.createTable(noteHistoryState);
        await m.createIndex(noteRevisionsNoteCreated);
      }
      if (from < 10) {
        await m.addColumn(notes, notes.reminderAt);
        await m.addColumn(notes, notes.reminderRecurrence);
        await m.addColumn(notes, notes.reminderVersion);
        await m.addColumn(notes, notes.isReminderSynced);
        await m.addColumn(notes, notes.reminderSlot);
      }
      if (from < 11) {
        await m.addColumn(notes, notes.syncedTitle);
        await m.addColumn(notes, notes.syncedContent);
        await m.addColumn(notes, notes.syncedBackground);
        await m.addColumn(notes, notes.syncedState);
        await (update(notes)..where(
              (tbl) => tbl.isSynced.equals(true) & tbl.version.isNotNull(),
            ))
            .write(
              NotesCompanion.custom(
                syncedTitle: notes.title,
                syncedContent: notes.content,
                syncedBackground: notes.background,
                syncedState: notes.state,
              ),
            );

        // The server sends each feed entry once; only a sync with no cursor
        // repeats them.
        await (update(syncState)..where((tbl) => tbl.cursor.isNotNull())).write(
          const SyncStateCompanion(cursor: Value(null)),
        );
      }
      if (from < 12) {
        // Databases from the first releases still carry a created_at column.
        final existing = await customSelect(
          'PRAGMA table_info(notes)',
        ).map((row) => row.read<String>('name')).get();
        if (!existing.contains('created_at')) {
          await m.addColumn(notes, notes.createdAt);
        }
        if (!existing.contains('position')) {
          await m.addColumn(notes, notes.position);
        }
        // A sync with no cursor resends every note, with when it was made.
        await (update(syncState)..where((tbl) => tbl.cursor.isNotNull())).write(
          const SyncStateCompanion(cursor: Value(null)),
        );
      }
      if (from < 13) {
        await m.addColumn(notes, notes.positionedAt);
        // Resent notes say when each was dragged, so the order matches the
        // web's.
        await (update(syncState)..where((tbl) => tbl.cursor.isNotNull())).write(
          const SyncStateCompanion(cursor: Value(null)),
        );
      }
      if (from < 14) {
        final existing = await customSelect(
          'PRAGMA table_info(note_attachments)',
        ).map((row) => row.read<String>('name')).get();
        if (!existing.contains('picture_text')) {
          await m.addColumn(noteAttachments, noteAttachments.pictureText);
        }
        // Resent attachments bring the text read from each picture.
        await (update(syncState)..where((tbl) => tbl.cursor.isNotNull())).write(
          const SyncStateCompanion(cursor: Value(null)),
        );
      }
      if (from < 15) {
        final existing = await customSelect(
          'PRAGMA table_info(tags)',
        ).map((row) => row.read<String>('name')).get();
        if (!existing.contains('position')) {
          await m.addColumn(tags, tags.position);
        }
        // Resent tags bring where each was dragged.
        await (update(syncState)..where((tbl) => tbl.cursor.isNotNull())).write(
          const SyncStateCompanion(cursor: Value(null)),
        );
      }
      if (from < 16) {
        final existing = await customSelect(
          'PRAGMA table_info(notes)',
        ).map((row) => row.read<String>('name')).get();
        if (!existing.contains('lock')) {
          await m.addColumn(notes, notes.lock);
        }
        // Not known until the feed resends the notes, so an edit waiting to
        // go up doesn't take off a lock set elsewhere.
        await update(
          notes,
        ).write(const NotesCompanion(lock: Value(unknownNoteLock)));
        await (update(syncState)..where((tbl) => tbl.cursor.isNotNull())).write(
          const SyncStateCompanion(cursor: Value(null)),
        );
      }
    },
  );
}

LazyDatabase _openConnection(String userId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final userDbFile = File(path.join(dbFolder.path, 'db_$userId.sqlite'));

    if (!userDbFile.existsSync()) {
      final legacyFile = File(path.join(dbFolder.path, 'db.sqlite'));
      if (legacyFile.existsSync()) {
        await legacyFile.rename(userDbFile.path);
      }
    }

    return NativeDatabase.createInBackground(userDbFile);
  });
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) {
    throw StateError('No active user - database unavailable');
  }
  final db = AppDatabase(userId);
  ref.onDispose(() => db.close());
  return db;
}
