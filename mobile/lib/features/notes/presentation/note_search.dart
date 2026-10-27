import '../../../core/widgets/quill_preview.dart';
import '../domain/note.dart';

/// Whether [note] has [query] in its title, its text or the text read from
/// its pictures; any note matches an empty query. A locked note not opened
/// this session ([titleOnly]) is found by its title alone, so a match
/// gives nothing of its text away.
bool noteMatchesSearch(Note note, String query, {bool titleOnly = false}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (note.title.toLowerCase().contains(q)) return true;
  if (titleOnly) return false;
  return extractPlainTextFromQuillContent(
        note.content,
      ).toLowerCase().contains(q) ||
      note.pictureText.toLowerCase().contains(q);
}
