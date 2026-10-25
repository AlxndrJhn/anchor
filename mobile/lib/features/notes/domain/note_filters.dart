import 'note.dart';

/// Narrows the notes list on top of a search, as the web's Filter menu does.
/// The tag filter is the list's own (selectedTagFilterProvider).
class NoteFilters {
  const NoteFilters({
    this.background,
    this.picture = false,
    this.checklist = false,
    this.reminder = false,
  });

  /// A background id (a colour or a pattern).
  final String? background;
  final bool picture;
  final bool checklist;
  final bool reminder;

  static const none = NoteFilters();

  int get count =>
      (background != null ? 1 : 0) +
      (picture ? 1 : 0) +
      (checklist ? 1 : 0) +
      (reminder ? 1 : 0);

  bool get isEmpty => count == 0;

  NoteFilters copyWith({
    String? Function()? background,
    bool? picture,
    bool? checklist,
    bool? reminder,
  }) => NoteFilters(
    background: background != null ? background() : this.background,
    picture: picture ?? this.picture,
    checklist: checklist ?? this.checklist,
    reminder: reminder ?? this.reminder,
  );

  bool matches(Note note) =>
      (background == null || note.background == background) &&
      (!picture || note.imagePreviewData.isNotEmpty) &&
      (!checklist || hasChecklist(note)) &&
      (!reminder || note.hasReminder);

  @override
  bool operator ==(Object other) =>
      other is NoteFilters &&
      other.background == background &&
      other.picture == picture &&
      other.checklist == checklist &&
      other.reminder == reminder;

  @override
  int get hashCode => Object.hash(background, picture, checklist, reminder);
}

final _checklistAttribute = RegExp(r'"list"\s*:\s*"(?:un)?checked"');

/// Whether the note has a checklist item, ticked or not.
bool hasChecklist(Note note) =>
    _checklistAttribute.hasMatch(note.content ?? '');
