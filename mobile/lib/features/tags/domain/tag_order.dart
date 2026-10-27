import 'tag.dart';

/// The tag ids after the one at [oldIndex] was moved to [newIndex].
List<String> movedTagIds(List<Tag> tags, int oldIndex, int newIndex) {
  final ids = [for (final t in tags) t.id];
  ids.insert(newIndex, ids.removeAt(oldIndex));
  return ids;
}

/// [tags] in the order of [ids], while the stored order catches up; [tags]
/// as they are when they're no longer the same tags.
List<Tag> inIdOrder(List<Tag> tags, List<String> ids) {
  if (tags.length != ids.length) return tags;
  final byId = {for (final t in tags) t.id: t};
  final ordered = [for (final id in ids) ?byId[id]];
  return ordered.length == tags.length ? ordered : tags;
}
