import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'document_lines.dart';

/// The change that adds [text] as new lines at the end of [document]
/// ("Grab image text"); null when there is no text.
///
/// Composed as is: Quill's insert rules would copy the last line's style.
/// The last line keeps its style on a newline of its own; the note's final
/// newline then ends the new text, as a plain line.
Delta? appendLinesDelta(Document document, String text) {
  final lines = text.trim();
  if (lines.isEmpty) return null;
  final last = parseDocumentLines(document).last;
  final attributes = last.newlineAttributes ?? const <String, dynamic>{};
  final isBlank = document.length == 1 && attributes.isEmpty;
  return isBlank
      ? (Delta()..insert(lines))
      : (Delta()
          ..retain(document.length - 1)
          ..insert('\n', attributes.isEmpty ? null : attributes)
          ..insert(lines)
          ..retain(1, {for (final key in attributes.keys) key: null}));
}

/// Stored note content with [text] added as new lines at the end, as the
/// editor's `appendText` does; for adding to a note that isn't open (a
/// picture opened from its card). Null when there is nothing to add.
String? appendTextContent(String? content, String text) {
  var document = Document();
  try {
    final json = jsonDecode(content ?? '');
    if (json is Map && json['ops'] is List) {
      document = Document.fromJson(json['ops'] as List);
    }
  } catch (_) {
    // Unreadable or empty content: the text starts the note.
  }
  final change = appendLinesDelta(document, text);
  if (change == null) return null;
  document.compose(change, ChangeSource.local);
  return jsonEncode({'ops': document.toDelta().toJson()});
}
