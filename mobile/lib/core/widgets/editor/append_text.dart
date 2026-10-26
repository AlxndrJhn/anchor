import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Stored note content with [text] added as new lines at the end, as the
/// editor's `appendText` does; for adding to a note that isn't open.
String appendTextContent(String? content, String text) {
  var document = Document();
  try {
    final json = jsonDecode(content ?? '');
    if (json is Map && json['ops'] is List) {
      document = Document.fromJson(json['ops'] as List);
    }
  } catch (_) {
    // Unreadable or empty content: the text starts the note.
  }
  final isEmpty = document.toPlainText().trim().isEmpty;
  document.insert(document.length - 1, isEmpty ? text : '\n$text');
  return jsonEncode({'ops': document.toDelta().toJson()});
}
