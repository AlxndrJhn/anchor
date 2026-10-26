import '../../../core/widgets/quill_preview.dart';
import '../domain/note.dart';

/// Whether [note] has [query] in its title, its text or the text read from
/// its pictures; any note matches an empty query.
bool noteMatchesSearch(Note note, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return note.title.toLowerCase().contains(q) ||
      extractPlainTextFromQuillContent(
        note.content,
      ).toLowerCase().contains(q) ||
      note.pictureText.toLowerCase().contains(q);
}
