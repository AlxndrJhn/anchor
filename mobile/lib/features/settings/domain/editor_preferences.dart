import '../../../core/theme/note_typography.dart';

class EditorPreferences {
  /// Sorts checked items to the bottom.
  final bool sortChecklistItems;

  /// Deleted notes burn away where they stood, on this device.
  final bool burnDeleted;

  final NoteFont noteFont;
  final NoteTextSize noteTextSize;

  const EditorPreferences({
    this.sortChecklistItems = true,
    this.burnDeleted = true,
    this.noteFont = NoteFont.sans,
    this.noteTextSize = NoteTextSize.standard,
  });

  EditorPreferences copyWith({
    bool? sortChecklistItems,
    bool? burnDeleted,
    NoteFont? noteFont,
    NoteTextSize? noteTextSize,
  }) {
    return EditorPreferences(
      sortChecklistItems: sortChecklistItems ?? this.sortChecklistItems,
      burnDeleted: burnDeleted ?? this.burnDeleted,
      noteFont: noteFont ?? this.noteFont,
      noteTextSize: noteTextSize ?? this.noteTextSize,
    );
  }
}
