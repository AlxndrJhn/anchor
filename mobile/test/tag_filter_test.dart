import 'dart:async';

import 'package:anchor/features/tags/data/repository/tags_repository.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTagsRepository extends Mock implements TagsRepository {}

void main() {
  late StreamController<List<Tag>> stored;
  late ProviderContainer container;

  const work = Tag(id: 'local', name: 'Work');
  const home = Tag(id: 'home', name: 'home');

  setUp(() {
    stored = StreamController<List<Tag>>.broadcast();
    final repo = MockTagsRepository();
    when(repo.watchTags).thenAnswer((_) => stored.stream);
    container = ProviderContainer(
      overrides: [tagsRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(selectedTagFilterProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await stored.close();
  });

  Future<void> store(List<Tag> tags) async {
    stored.add(tags);
    await Future<void>.delayed(Duration.zero);
  }

  String? filter() => container.read(selectedTagFilterProvider);

  test('the tag filter clears once its tag is deleted elsewhere', () async {
    await store([work, home]);
    container.read(selectedTagFilterProvider.notifier).select(work.id);

    await store([home]);

    expect(filter(), isNull);
  });

  test('the tag filter follows its tag into one of the same name', () async {
    await store([work, home]);
    container.read(selectedTagFilterProvider.notifier).select(work.id);

    await store([home, const Tag(id: 'server', name: 'work')]);

    expect(filter(), 'server');
  });

  test('the tag filter stays on a tag renamed elsewhere', () async {
    await store([work, home]);
    container.read(selectedTagFilterProvider.notifier).select(work.id);

    await store([work.copyWith(name: 'Office'), home]);

    expect(filter(), work.id);
  });
}
