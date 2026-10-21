import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repository/note_revisions_store.dart';
import '../domain/note_history.dart';
import '../domain/note_revision.dart';

part 'note_history_controller.g.dart';

/// A note's versions kept on this phone, newest first.
@riverpod
Stream<List<NoteRevision>> noteRevisions(Ref ref, String noteId) =>
    ref.watch(noteRevisionsStoreProvider).watch(noteId);

@riverpod
Stream<NoteHistoryPosition> noteHistoryPosition(Ref ref, String noteId) =>
    ref.watch(noteRevisionsStoreProvider).watchPosition(noteId);

@riverpod
VersionChanges versionChanges(Ref ref, String noteId) => VersionChanges();
