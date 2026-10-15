import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../core/theme/note_typography.dart';
import '../domain/editor_preferences.dart';

part 'editor_preferences_controller.g.dart';

@Riverpod(keepAlive: true)
class EditorPreferencesController extends _$EditorPreferencesController {
  @override
  EditorPreferences build() =>
      ref.watch(appBootstrapProvider).editorPreferences;

  Future<void> setSortChecklistItems(bool value) async {
    state = state.copyWith(sortChecklistItems: value);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setSortChecklistItems(value);
  }

  Future<void> setNoteFont(NoteFont font) async {
    state = state.copyWith(noteFont: font);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setNoteFont(font.name);
  }

  Future<void> setNoteTextSize(NoteTextSize textSize) async {
    state = state.copyWith(noteTextSize: textSize);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setNoteTextSize(textSize.name);
  }
}
