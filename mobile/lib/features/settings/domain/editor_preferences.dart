import '../../../core/theme/note_typography.dart';

class EditorPreferences {
  /// Sorts checked items to the bottom.
  final bool sortChecklistItems;

  final NoteFont noteFont;
  final NoteTextSize noteTextSize;

  const EditorPreferences({
    this.sortChecklistItems = true,
    this.noteFont = NoteFont.sans,
    this.noteTextSize = NoteTextSize.standard,
  });

  EditorPreferences copyWith({
    bool? sortChecklistItems,
    NoteFont? noteFont,
    NoteTextSize? noteTextSize,
  }) {
    return EditorPreferences(
      sortChecklistItems: sortChecklistItems ?? this.sortChecklistItems,
      noteFont: noteFont ?? this.noteFont,
      noteTextSize: noteTextSize ?? this.noteTextSize,
    );
  }
}
