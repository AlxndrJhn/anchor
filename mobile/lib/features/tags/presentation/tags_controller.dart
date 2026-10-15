import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ids.dart';
import '../../notes/presentation/notes_controller.dart';
import '../data/repository/tags_repository.dart';
import '../domain/tag.dart';

part 'tags_controller.g.dart';

@riverpod
class TagsController extends _$TagsController {
  @override
  Stream<List<Tag>> build() {
    return ref.watch(tagsRepositoryProvider).watchTags();
  }

  /// Throws [TagNameTakenException] when another tag has the name.
  Future<Tag> createTag(String name, {String? color}) async {
    final tagName = await _checkedName(name);
    final tag = Tag(
      id: newId(),
      name: tagName,
      color: color ?? generateRandomTagColor(),
      isSynced: false,
    );
    return ref.read(tagsRepositoryProvider).createTag(tag);
  }

  /// Throws [TagNameTakenException] when another tag has the new name.
  Future<void> updateTag(Tag tag) async {
    final tagName = await _checkedName(tag.name, tagId: tag.id);
    await ref
        .read(tagsRepositoryProvider)
        .updateTag(tag.copyWith(name: tagName));
  }

  Future<String> _checkedName(String name, {String? tagId}) async {
    final tagName = name.trim();
    if (tagName.isEmpty) throw ArgumentError('Tag name cannot be empty');
    final tags = await ref.read(tagsRepositoryProvider).getTags();
    if (isTagNameTaken(tags, tagName, exceptId: tagId)) {
      throw TagNameTakenException(tagName);
    }
    return tagName;
  }

  Future<void> deleteTag(String id) async {
    await ref.read(tagsRepositoryProvider).deleteTag(id);
  }
}

/// Counts archived notes too.
@riverpod
Map<String, int> tagNoteCounts(Ref ref) {
  final notes = [
    ...?ref.watch(allActiveNotesProvider).value,
    ...?ref.watch(archivedNotesProvider).value,
  ];
  final counts = <String, int>{};
  for (final note in notes) {
    for (final tagId in note.tagIds) {
      counts[tagId] = (counts[tagId] ?? 0) + 1;
    }
  }
  return counts;
}

@riverpod
class SelectedTagFilter extends _$SelectedTagFilter {
  @override
  String? build() {
    ref.listen(tagsControllerProvider, (previous, next) {
      final id = state;
      final tags = next.value;
      if (id == null || tags == null || tags.any((tag) => tag.id == id)) {
        return;
      }
      final name = previous?.value
          ?.where((tag) => tag.id == id)
          .firstOrNull
          ?.name
          .toLowerCase();
      state = tags
          .where((tag) => tag.name.toLowerCase() == name)
          .firstOrNull
          ?.id;
    });
    return null;
  }

  void select(String? tagId) {
    state = tagId;
  }

  void clear() {
    state = null;
  }
}
