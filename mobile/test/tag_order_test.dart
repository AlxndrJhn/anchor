import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/sync/data/sync_api.dart';
import 'package:anchor/features/tags/data/repository/tags_repository.dart';
import 'package:anchor/features/tags/domain/tag.dart' as domain;
import 'package:anchor/features/tags/domain/tag_order.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TagsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> add(String id, String name) =>
      repo.createTag(domain.Tag(id: id, name: name));

  Future<List<String>> names() async => [
    for (final t in await repo.watchTags().first) t.name,
  ];

  test('lists tags by name until they are dragged', () async {
    await add('w', 'work');
    await add('h', 'home');
    await add('i', 'ideas');

    expect(await names(), ['home', 'ideas', 'work']);
  });

  test('keeps the dragged order, and sends only the moved tags', () async {
    await add('w', 'work');
    await add('h', 'home');
    await add('i', 'ideas');
    await (db.update(
      db.tags,
    )).write(const TagsCompanion(isSynced: Value(true)));

    await repo.reorderTags(['w', 'h', 'i']);
    expect(await names(), ['work', 'home', 'ideas']);

    await (db.update(
      db.tags,
    )).write(const TagsCompanion(isSynced: Value(true)));
    await repo.reorderTags(['w', 'i', 'h']);
    final unsent = await (db.select(
      db.tags,
    )..where((t) => t.isSynced.equals(false))).get();
    expect(unsent.map((t) => t.id), unorderedEquals(['i', 'h']));
    expect(await names(), ['work', 'ideas', 'home']);
  });

  test('a new tag comes after the dragged ones', () async {
    await add('w', 'work');
    await add('h', 'home');
    await repo.reorderTags(['w', 'h']);
    await add('a', 'art');

    expect(await names(), ['work', 'home', 'art']);
  });

  test('the order rides along with the tag to the server', () {
    const change = SyncTagChange(
      id: 't',
      localRev: 2,
      baseVersion: 1,
      name: 'work',
      color: null,
      isDeleted: false,
      position: 3,
    );
    expect(change.toJson()['position'], 3);
    expect(
      SyncServerTag.fromJson({
        'id': 't',
        'name': 'work',
        'position': 1,
      }).position,
      1,
    );
  });

  test('movedTagIds moves one tag', () {
    final tags = [
      for (final id in ['a', 'b', 'c']) domain.Tag(id: id, name: id),
    ];
    expect(movedTagIds(tags, 0, 2), ['b', 'c', 'a']);
    expect(movedTagIds(tags, 2, 0), ['c', 'a', 'b']);
    expect(inIdOrder(tags, ['c', 'b', 'a']).map((t) => t.id), ['c', 'b', 'a']);
  });
}
