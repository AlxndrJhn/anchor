import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/sync_requester.dart';
import '../../domain/tag.dart';
import '../local/tag_rows.dart';

part 'tags_repository.g.dart';

@Riverpod(keepAlive: true)
TagsRepository tagsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return TagsRepository(db);
}

/// Nothing here talks to the server.
class TagsRepository {
  final AppDatabase _db;

  TagsRepository(this._db);

  Stream<List<Tag>> watchTags() {
    return _liveTags().watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  Future<List<Tag>> getTags() async {
    final rows = await _liveTags().get();
    return rows.map(_mapToDomain).toList();
  }

  Future<Tag> createTag(Tag tag) async {
    final created = tag.copyWith(updatedAt: DateTime.now().toUtc());

    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(
            id: created.id,
            name: created.name,
            color: drift.Value(created.color),
            updatedAt: drift.Value(created.updatedAt),
            isSynced: const drift.Value(false),
            localRev: const drift.Value(1),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

    scheduleAppSync(trigger: 'TagsRepo.createTag');

    return created;
  }

  Future<void> updateTag(Tag tag) async {
    await _db.transaction(() async {
      final prior = await _db.tagRow(tag.id);
      if (prior == null) return;

      await _db.writeTag(
        tag.id,
        TagsCompanion(
          name: drift.Value(tag.name),
          color: drift.Value(tag.color),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          isSynced: const drift.Value(false),
          localRev: drift.Value(prior.localRev + 1),
        ),
      );
    });

    scheduleAppSync(trigger: 'TagsRepo.updateTag');
  }

  /// Puts the tags in the order of [ids], as they were dragged. Only the
  /// tags that moved change; their version doesn't.
  Future<void> reorderTags(List<String> ids) async {
    var moved = false;
    await _db.transaction(() async {
      final rows = await (_db.select(
        _db.tags,
      )..where((tbl) => tbl.id.isIn(ids) & tbl.isDeleted.equals(false))).get();
      final byId = {for (final row in rows) row.id: row};
      final placed = ids.where(byId.containsKey).toList();
      for (var i = 0; i < placed.length; i++) {
        final row = byId[placed[i]]!;
        if (row.position == i) continue;
        moved = true;
        await _db.writeTag(
          row.id,
          TagsCompanion(
            position: drift.Value(i.toDouble()),
            isSynced: const drift.Value(false),
            localRev: drift.Value(row.localRev + 1),
          ),
        );
      }
    });
    if (moved) scheduleAppSync(trigger: 'TagsRepo.reorderTags');
  }

  // Kept, marked deleted, until the server has been told.
  Future<void> deleteTag(String id) async {
    await _db.transaction(() async {
      final prior = await _db.tagRow(id);
      if (prior == null) return;

      await _db.writeTag(
        id,
        TagsCompanion(
          isDeleted: const drift.Value(true),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          isSynced: const drift.Value(false),
          localRev: drift.Value(prior.localRev + 1),
        ),
      );
      await (_db.delete(
        _db.noteTags,
      )..where((tbl) => tbl.tagId.equals(id))).go();
    });

    scheduleAppSync(trigger: 'TagsRepo.deleteTag');
  }

  drift.SimpleSelectStatement<$TagsTable, TagRow> _liveTags() {
    return _db.select(_db.tags)
      ..where((tbl) => tbl.isDeleted.equals(false))
      // Dragged tags first, in their order; the rest after, by name.
      ..orderBy([
        (tbl) => drift.OrderingTerm(
          expression: tbl.position,
          nulls: drift.NullsOrder.last,
        ),
        (tbl) => drift.OrderingTerm(expression: tbl.name),
      ]);
  }

  Tag _mapToDomain(TagRow row) {
    return Tag(
      id: row.id,
      name: row.name,
      color: row.color,
      position: row.position,
      updatedAt: row.updatedAt,
      isSynced: row.isSynced,
      isDeleted: row.isDeleted,
    );
  }
}
