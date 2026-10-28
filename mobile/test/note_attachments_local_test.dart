import 'dart:convert';
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart' as domain;
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local attachment bookkeeping against an in-memory Drift DB. No network.
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
    domain.AttachmentSyncStatus status = domain.AttachmentSyncStatus.synced,
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

  Future<Note> readNote(String id) =>
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
      expect(row.syncStatus, domain.AttachmentSyncStatus.pendingDelete.dbValue);

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
        status: domain.AttachmentSyncStatus.pendingUpload,
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

  test('deleting an unknown attachment leaves the note alone', () async {
    await insertNote('n1');

    await repo.deleteAttachment('n1', 'missing');

    expect((await readNote('n1')).updatedAt!.isAtSameMomentAs(past), isTrue);
  });

  test('the server\'s attachments bring the text read from pictures', () async {
    await insertNote('n1');

    await repo.applyServerAttachments('n1', [
      domain.NoteAttachment.fromJson({
        'id': 'a1',
        'noteId': 'n1',
        'type': 'image',
        'originalFilename': 'receipt.png',
        'mimeType': 'image/png',
        'fileSize': 10,
        'position': 0,
        'text': 'Kassenbon EUR 4,20',
      }),
    ]);

    final row = await db.select(db.noteAttachments).getSingle();
    expect(row.pictureText, 'Kassenbon EUR 4,20');
  });

  group('uploading', () {
    late Directory tmp;
    late List<RequestOptions> sent;

    /// The server's answer to an upload: the attachment it made, with [id].
    void answerUploadsWith(String Function(FormData form) id) {
      repo = NoteAttachmentsRepository(
        db,
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                sent.add(options);
                final form = options.data as FormData;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 201,
                    data: {
                      'id': id(form),
                      'noteId': 'n1',
                      'type': 'image',
                      'originalFilename': 'a.png',
                      'mimeType': 'image/png',
                      'fileSize': 1,
                      'position': 0,
                    },
                  ),
                );
              },
            ),
          ),
      );
    }

    setUp(() async {
      sent = [];
      tmp = await Directory.systemTemp.createTemp('attachments');
    });

    tearDown(() => tmp.delete(recursive: true));

    Future<void> pendingUpload(String id, {String? content}) async {
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              id: 'n1',
              title: 'Note',
              content: Value(content),
              isSynced: const Value(true),
            ),
          );
      final file = File('${tmp.path}/a.png')..writeAsBytesSync([1]);
      await db
          .into(db.noteAttachments)
          .insert(
            NoteAttachmentsCompanion.insert(
              id: id,
              noteId: 'n1',
              type: 'image',
              originalFilename: 'a.png',
              mimeType: 'image/png',
              fileSize: 1,
              localPath: Value(file.path),
              syncStatus: Value(
                domain.AttachmentSyncStatus.pendingUpload.dbValue,
              ),
            ),
          );
    }

    String contentShowing(String id) => jsonEncode({
      'ops': [
        {
          'insert': {
            'note-image': jsonEncode({'id': id}),
          },
        },
        {'insert': '\n'},
      ],
    });

    test('sends the id the picture in the text knows it by', () async {
      answerUploadsWith(
        (form) => form.fields.firstWhere((f) => f.key == 'id').value,
      );
      await pendingUpload('local-1', content: contentShowing('local-1'));

      await repo.sync();

      final fields = (sent.single.data as FormData).fields;
      expect(fields.map((f) => '${f.key}=${f.value}'), contains('id=local-1'));
      final note = await readNote('n1');
      expect(note.content, contentShowing('local-1'));
      expect(note.isSynced, isTrue);
      expect(await repo.watchAttachment('local-1').first, isNotNull);
    });

    test('an older server\'s new id is put in the text', () async {
      answerUploadsWith((_) => 'server-1');
      await pendingUpload('local-1', content: contentShowing('local-1'));

      await repo.sync();

      final note = await readNote('n1');
      expect(note.content, contentShowing('server-1'));
      expect(note.isSynced, isFalse);
      expect(await repo.watchAttachment('server-1').first, isNotNull);
      expect(await repo.watchAttachment('local-1').first, isNull);
    });
  });

  test(
    'pictures without a file on the device are the ones to download',
    () async {
      await insertNote('n1');
      await insertAttachment('a1', 'n1');
      await insertAttachment('a2', 'n1');
      await insertAttachment(
        'a3',
        'n1',
        status: domain.AttachmentSyncStatus.pendingUpload,
      );
      final kept = File(
        '${Directory.systemTemp.createTempSync('anchor').path}/a2.png',
      )..writeAsBytesSync([1]);
      await (db.update(db.noteAttachments)..where((tbl) => tbl.id.equals('a2')))
          .write(NoteAttachmentsCompanion(localPath: Value(kept.path)));

      // a2 is here, a3 isn't uploaded yet: only a1 is missing.
      expect(await repo.imagesToDownload(), [('n1', 'a1', 'a.png')]);

      // A file the system deleted counts as missing again.
      kept.deleteSync();
      expect((await repo.imagesToDownload()).map((e) => e.$2), ['a1', 'a2']);
    },
  );
}
