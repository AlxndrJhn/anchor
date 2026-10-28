import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/search/search_pattern.dart';
import '../../../core/widgets/quill_preview.dart';

import '../domain/note.dart';

export '../../../core/search/search_pattern.dart';

class SearchOptionsController extends Notifier<SearchOptions> {
  @override
  SearchOptions build() => const SearchOptions();

  void set(SearchOptions options) => state = options;
}

/// The notes list's search options, kept while the app runs.
final searchOptionsProvider =
    NotifierProvider<SearchOptionsController, SearchOptions>(
      SearchOptionsController.new,
    );

/// Whether [note] has [query] in its title, its text or the text read from
/// its pictures; any note matches an empty query. A locked note not opened
/// this session ([titleOnly]) is found by its title alone, so a match
/// gives nothing of its text away.
bool noteMatchesSearch(
  Note note,
  String query, {
  bool titleOnly = false,
  SearchOptions options = const SearchOptions(),
}) => noteMatchesPattern(
  note,
  SearchPattern(query, options: options),
  titleOnly: titleOnly,
);

/// [noteMatchesSearch] for a pattern made once for many notes.
bool noteMatchesPattern(
  Note note,
  SearchPattern pattern, {
  bool titleOnly = false,
}) {
  if (pattern.isEmpty) return true;
  if (pattern.hasMatch(note.title)) return true;
  if (titleOnly) return false;
  return pattern.hasMatch(extractPlainTextFromQuillContent(note.content)) ||
      pattern.hasMatch(note.pictureText);
}
