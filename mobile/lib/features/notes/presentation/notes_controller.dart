import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../tags/presentation/tags_controller.dart';
import '../data/repository/notes_repository.dart';
import '../domain/note.dart';

part 'notes_controller.g.dart';

/// The notes in Notes, filtered by the selected tag.
@riverpod
Stream<List<Note>> notes(Ref ref) {
  final selectedTagId = ref.watch(selectedTagFilterProvider);
  return ref.watch(notesRepositoryProvider).watchNotes(tagId: selectedTagId);
}

/// Null once the note is gone.
@riverpod
Stream<Note?> note(Ref ref, String id) =>
    ref.watch(notesRepositoryProvider).watchNote(id);

@riverpod
Stream<List<Note>> archivedNotes(Ref ref) {
  return ref.watch(notesRepositoryProvider).watchArchivedNotes();
}

@riverpod
Stream<List<Note>> trashedNotes(Ref ref) {
  return ref.watch(notesRepositoryProvider).watchTrashedNotes();
}

@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void set(String query) {
    state = query;
  }
}

@riverpod
class SelectionMode extends _$SelectionMode {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

@riverpod
class SelectedNoteIds extends _$SelectedNoteIds {
  @override
  Set<String> build() => {};

  void toggle(String id) => state = state.contains(id)
      ? {...state.where((selected) => selected != id)}
      : {...state, id};

  void selectAll(List<String> ids) => state = {...ids};

  void clear() => state = {};

  void add(String id) => state = {...state, id};
}

@riverpod
int unsyncedNoteCount(Ref ref) {
  final notes = ref.watch(allActiveNotesProvider).value ?? const <Note>[];
  return notes.where((note) => !note.isSynced).length;
}

/// Every note in Notes, whatever tag the list is filtered by.
@Riverpod(keepAlive: true)
Stream<List<Note>> allActiveNotes(Ref ref) {
  return ref.watch(notesRepositoryProvider).watchNotes();
}
