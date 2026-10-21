import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/storage/preferences_repository.dart';

part 'checked_folds_controller.g.dart';

@Riverpod(keepAlive: true)
class CheckedFolds extends _$CheckedFolds {
  static const _maxNotes = 500;

  @override
  Set<String> build() => {
    ...ref.watch(appBootstrapProvider).foldedChecklistNotes,
  };

  Future<void> setFolded(String noteId, {required bool isFolded}) async {
    if (state.contains(noteId) == isFolded) return;
    final next = {...state}..remove(noteId);
    if (isFolded) next.add(noteId);
    state = next;
    await ref
        .read(preferencesRepositoryProvider)
        .setFoldedChecklistNotes(
          next.skip(math.max(0, next.length - _maxNotes)).toList(),
        );
  }
}
