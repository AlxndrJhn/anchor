import 'dart:convert';
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/notes_backup.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart' as domain;
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backups against in-memory Drift DBs and a temp folder. No network.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  late AppDatabase source;
  late AppDatabase target;

  NotesBackup backupOf(AppDatabase db) => NotesBackup(
    db,
    fileOf: (row) async => row.localPath,
    filesDir: () async => Directory('${temp.path}/docs'),
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('anchor_backup_test');
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
    await temp.delete(recursive: true);
  });

  Future<void> insertNote(
    AppDatabase db,
    String id, {
    String title = 'Note',
    String? content,
    String state = 'active',
    bool isPinned = false,
    String? lock,
    String? reminderAt,
  }) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          id: id,
          title: title,
          content: Value(content),
          state: Value(state),
          isPinned: Value(isPinned),
          lock: Value(lock),
          reminderAt: Value(reminderAt),
          reminderRecurrence: Value(reminderAt == null ? null : 'weekly'),
          createdAt: Value(DateTime.utc(2021, 3, 4)),
          updatedAt: Value(DateTime.utc(2022, 5, 6)),
          isSynced: const Value(true),
          version: const Value(3),
        ),
      );

  Future<void> insertTag(AppDatabase db, String id, String name) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          id: id,
          name: name,
          color: const Value('#E57373'),
          isSynced: const Value(true),
        ),
      );

  Future<void> insertImage(AppDatabase db, String id, String noteId) async {
    final file = File('${temp.path}/cache/$id-cat.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3, 4]);
    await db
        .into(db.noteAttachments)
        .insert(
          NoteAttachmentsCompanion.insert(
            id: id,
            noteId: noteId,
            type: 'image',
            originalFilename: 'cat.png',
            mimeType: 'image/png',
            fileSize: 4,
            localPath: Value(file.path),
            serverAttachmentId: Value(id),
          ),
        );
  }

  test('a backup holds the notes, their tags and their files', () async {
    await insertTag(source, 't1', 'Work');
    await insertNote(source, 'n1', title: 'Hello', content: '[]');
    await insertNote(source, 'gone', state: 'deleted');
    await source
        .into(source.noteTags)
        .insert(NoteTagsCompanion.insert(noteId: 'n1', tagId: 't1'));
    await insertImage(source, 'a1', 'n1');

    final backup = await backupOf(
      source,
    ).export(now: DateTime.utc(2026, 10, 28));

    expect(backup.filename, 'anchor-backup-2026-10-28.zip');
    expect(backup.notes, 1);
    expect(backup.files, 1);
    final archive = ZipDecoder().decodeBytes(backup.bytes);
    final manifest =
        jsonDecode(utf8.decode(archive.findFile(backupManifestName)!.content))
            as Map<String, dynamic>;
    expect(manifest['format'], backupFormat);
    final notes = manifest['notes'] as List;
    expect(notes.single['title'], 'Hello');
    expect(notes.single['tagIds'], ['t1']);
    final file = notes.single['attachments'].single['file'] as String;
    expect(archive.findFile(file)!.content, [1, 2, 3, 4]);
  });

  test('an attachment that can’t be read is left out and counted', () async {
    await insertNote(source, 'n1');
    await insertImage(source, 'a1', 'n1');
    final backup = await NotesBackup(
      source,
      fileOf: (_) async => throw Exception('offline'),
      filesDir: () async => temp,
    ).export();

    expect(backup.files, 0);
    expect(backup.missingFiles, 1);
  });

  test('restoring brings missing notes back as new, unsynced notes', () async {
    await insertTag(source, 't1', 'Work');
    await insertTag(source, 't2', 'Home');
    await insertNote(
      source,
      'n1',
      title: 'Hello',
      content: '[{"insert":"hi\\n"}]',
      isPinned: true,
      lock: 'pin',
      reminderAt: '2030-01-01T09:00',
    );
    await insertNote(source, 'n2', title: 'Old', state: 'trashed');
    await source
        .into(source.noteTags)
        .insert(NoteTagsCompanion.insert(noteId: 'n1', tagId: 't1'));
    await source
        .into(source.noteTags)
        .insert(NoteTagsCompanion.insert(noteId: 'n1', tagId: 't2'));
    await insertImage(source, 'a1', 'n1');
    final backup = await backupOf(source).export();

    // This device already has "work" under another id.
    await insertTag(target, 'local-work', 'work');

    final summary = await backupOf(target).restore(backup.bytes);

    expect(summary.notes, 2);
    expect(summary.skipped, 0);
    expect(summary.tags, 1);
    expect(summary.files, 1);

    final notes = await target.select(target.notes).get();
    final hello = notes.singleWhere((n) => n.title == 'Hello');
    expect(hello.id, isNot('n1'));
    expect(hello.content, '[{"insert":"hi\\n"}]');
    expect(hello.isSynced, isFalse);
    expect(hello.version, isNull);
    expect(hello.permission, 'owner');
    expect(hello.isPinned, isTrue);
    expect(hello.isPinSynced, isFalse);
    expect(hello.lock, 'pin');
    expect(hello.reminderAt, '2030-01-01T09:00');
    expect(hello.reminderRecurrence, 'weekly');
    expect(hello.isReminderSynced, isFalse);
    expect(hello.reminderSlot, isNotNull);
    expect(hello.createdAt!.toUtc(), DateTime.utc(2021, 3, 4));
    expect(notes.singleWhere((n) => n.title == 'Old').state, 'trashed');

    final tagIds =
        await (target.select(target.noteTags)
              ..where((tbl) => tbl.noteId.equals(hello.id)))
            .map((row) => row.tagId)
            .get();
    final home = await (target.select(
      target.tags,
    )..where((tbl) => tbl.name.equals('Home'))).getSingle();
    expect(tagIds.toSet(), {'local-work', home.id});
    expect(home.isSynced, isFalse);

    final attachment = await (target.select(
      target.noteAttachments,
    )..where((tbl) => tbl.noteId.equals(hello.id))).getSingle();
    expect(
      attachment.syncStatus,
      domain.AttachmentSyncStatus.pendingUpload.dbValue,
    );
    expect(attachment.localPath, startsWith('${temp.path}/docs/attachments/'));
    expect(await File(attachment.localPath!).readAsBytes(), [1, 2, 3, 4]);
  });

  test('restoring twice, or onto the same notes, adds nothing', () async {
    await insertNote(source, 'n1', title: 'Hello');
    final backup = await backupOf(source).export();

    final again = await backupOf(source).restore(backup.bytes);
    expect(again.notes, 0);
    expect(again.skipped, 1);

    expect((await backupOf(target).restore(backup.bytes)).notes, 1);
    final second = await backupOf(target).restore(backup.bytes);
    expect(second.notes, 0);
    expect(await target.select(target.notes).get(), hasLength(1));
  });

  test('a file that isn’t a backup is refused', () async {
    final notZip = utf8.encode('hello');
    expect(
      () => backupOf(target).restore(notZip),
      throwsA(isA<BackupFormatException>()),
    );

    final otherZip = Archive()
      ..addFile(ArchiveFile.bytes('readme.txt', utf8.encode('hi')));
    expect(
      () => backupOf(target).restore(ZipEncoder().encodeBytes(otherZip)),
      throwsA(isA<BackupFormatException>()),
    );

    final newer = Archive()
      ..addFile(
        ArchiveFile.bytes(
          backupManifestName,
          utf8.encode(jsonEncode({'format': backupFormat, 'version': 99})),
        ),
      );
    expect(
      () => backupOf(target).restore(ZipEncoder().encodeBytes(newer)),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
