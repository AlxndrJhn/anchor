import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

/// None opens a transaction: each runs inside its caller's.
extension NoteRows on AppDatabase {
  Future<NoteRow?> noteRow(String id) =>
      (select(notes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> writeNote(String id, NotesCompanion values) async {
    await (update(notes)..where((tbl) => tbl.id.equals(id))).write(values);
  }

  Expression<int> get nextLocalRev => notes.localRev + const Constant(1);

  Future<void> markNotesUnsynced(Iterable<String> ids) async {
    await (update(notes)..where((tbl) => tbl.id.isIn(ids))).write(
      NotesCompanion.custom(
        isSynced: const Constant(false),
        localRev: nextLocalRev,
      ),
    );
  }

  Future<List<String>> tagIdsOfNote(String noteId) {
    return (select(
      noteTags,
    )..where((tbl) => tbl.noteId.equals(noteId))).map((row) => row.tagId).get();
  }

  Future<void> setNoteTags(String noteId, List<String> tagIds) async {
    await (delete(noteTags)..where((tbl) => tbl.noteId.equals(noteId))).go();
    if (tagIds.isEmpty) return;

    await batch((batch) {
      batch.insertAll(noteTags, [
        for (final tagId in tagIds)
          NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
      ], mode: InsertMode.insertOrReplace);
    });
  }
}

String encodeShareIds(List<String> ids) => jsonEncode(ids);

List<String> decodeShareIds(String? stored) => stored == null || stored.isEmpty
    ? const []
    : List<String>.from(jsonDecode(stored) as List);
