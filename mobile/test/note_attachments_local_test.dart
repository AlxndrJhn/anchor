import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NoteAttachmentsRepository repo;

  final past = DateTime.utc(2020);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NoteAttachmentsRepository(db, Dio());
  });

  tearDown(() => db.close());

  Future<void> insertNote(String id) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          id: id,
          title: 'Note',
          updatedAt: Value(past),
          isSynced: const Value(true),
        ),
      );

  Future<void> insertAttachment(
    String id,
    String noteId, {
    AttachmentSyncStatus status = AttachmentSyncStatus.synced,
  }) => db
      .into(db.noteAttachments)
      .insert(
        NoteAttachmentsCompanion.insert(
          id: id,
          noteId: noteId,
          type: 'image',
          originalFilename: 'a.png',
          mimeType: 'image/png',
          fileSize: 1,
          syncStatus: Value(status.dbValue),
        ),
      );

  Future<NoteRow> readNote(String id) =>
      (db.select(db.notes)..where((tbl) => tbl.id.equals(id))).getSingle();

  test(
    'deleting an uploaded attachment queues it and restamps the note',
    () async {
      await insertNote('n1');
      await insertAttachment('a1', 'n1');

      await repo.deleteAttachment('n1', 'a1');

      final row = await (db.select(
        db.noteAttachments,
      )..where((tbl) => tbl.id.equals('a1'))).getSingle();
      expect(row.syncStatus, AttachmentSyncStatus.pendingDelete.dbValue);

      final note = await readNote('n1');
      expect(note.updatedAt!.isAfter(past), isTrue);
      expect(note.isSynced, isTrue);
    },
  );

  test(
    'deleting an attachment that never uploaded restamps the note',
    () async {
      await insertNote('n1');
      await insertAttachment(
        'a1',
        'n1',
        status: AttachmentSyncStatus.pendingUpload,
      );

      await repo.deleteAttachment('n1', 'a1');

      expect(
        await (db.select(
          db.noteAttachments,
        )..where((tbl) => tbl.id.equals('a1'))).getSingleOrNull(),
        isNull,
      );
      expect((await readNote('n1')).updatedAt!.isAfter(past), isTrue);
    },
  );

  test('a delete not sent yet survives the server list coming in', () async {
    await insertNote('n1');
    await insertAttachment('a1', 'n1');
    await repo.deleteAttachment('n1', 'a1');

    await repo.applyServerAttachments('n1', const [
      NoteAttachment(
        id: 'a1',
        noteId: 'n1',
        type: AttachmentType.image,
        originalFilename: 'a.png',
        mimeType: 'image/png',
        fileSize: 1,
      ),
    ]);

    final row = await (db.select(
      db.noteAttachments,
    )..where((tbl) => tbl.id.equals('a1'))).getSingle();
    expect(row.syncStatus, AttachmentSyncStatus.pendingDelete.dbValue);
    expect(await repo.watchAttachments('n1').first, isEmpty);
  });

  test('deleting an unknown attachment leaves the note alone', () async {
    await insertNote('n1');

    await repo.deleteAttachment('n1', 'missing');

    expect((await readNote('n1')).updatedAt!.isAtSameMomentAs(past), isTrue);
  });
}
