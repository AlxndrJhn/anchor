import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../domain/note_blocks.dart';

class ParsedLine {
  final int startOffset;

  /// Length including the trailing newline.
  final int length;
  final Map<String, dynamic>? newlineAttributes;

  ParsedLine({
    required this.startOffset,
    required this.length,
    required this.newlineAttributes,
  });

  String? get listType => newlineAttributes?[Attribute.list.key] as String?;
  bool get isChecklist => isChecklistValue(listType);
  bool get isChecked => listType == Attribute.checked.value;

  int get indent => (newlineAttributes?[Attribute.indent.key] as int?) ?? 0;
}

extension LineAttributes on Map<String, Attribute> {
  int get indentLevel => this[Attribute.indent.key]?.value as int? ?? 0;

  /// A checklist item, checked or not.
  bool get isChecklist => isChecklistValue(this[Attribute.list.key]?.value);
}

List<ParsedLine> parseDocumentLines(Document document) {
  final lines = <ParsedLine>[];
  var offset = 0;
  var lineStart = 0;

  for (final op in document.toDelta().toList()) {
    final data = op.data;
    if (data is! String) {
      // Embeds occupy one position and never contain a newline.
      offset += 1;
      continue;
    }

    var searchFrom = 0;
    while (true) {
      final newlineIndex = data.indexOf('\n', searchFrom);
      if (newlineIndex == -1) {
        offset += data.length - searchFrom;
        break;
      }
      offset += newlineIndex - searchFrom + 1;
      lines.add(
        ParsedLine(
          startOffset: lineStart,
          length: offset - lineStart,
          newlineAttributes: op.attributes,
        ),
      );
      lineStart = offset;
      searchFrom = newlineIndex + 1;
    }
  }

  return lines;
}

/// Index of the line holding the document [offset], or -1 past the end.
int lineIndexAt(List<ParsedLine> lines, int offset) {
  for (var i = 0; i < lines.length; i++) {
    if (offset >= lines[i].startOffset &&
        offset < lines[i].startOffset + lines[i].length) {
      return i;
    }
  }
  return -1;
}

Map<String, dynamic> indentAttributes(int indent) => {
  Attribute.indent.key: indent == 0 ? null : indent,
};

/// Indenting stops at [maxListIndent] and one level deeper than the list
/// line above. Null when nothing changes.
Delta? buildListIndentDelta(
  List<ParsedLine> lines,
  int start,
  int end, {
  required bool increase,
}) {
  final rangeEnd = end > start ? end : start + 1;
  final effective = <int>[];
  final delta = Delta();
  var cursor = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final newlineOffset = line.startOffset + line.length - 1;
    final inRange = line.startOffset < rangeEnd && start <= newlineOffset;
    var newIndent = line.indent;

    if (inRange && line.listType != null) {
      if (increase) {
        final isAfterList = i > 0 && lines[i - 1].listType != null;
        var cap = isAfterList ? effective[i - 1] + 1 : 0;
        if (cap > maxListIndent) cap = maxListIndent;
        final proposed = newIndent + 1;
        if (proposed <= cap) newIndent = proposed;
      } else if (newIndent > 0) {
        newIndent -= 1;
      }
    }
    effective.add(newIndent);

    if (newIndent != line.indent) {
      if (newlineOffset > cursor) {
        delta.retain(newlineOffset - cursor);
      }
      delta.retain(1, indentAttributes(newIndent));
      cursor = newlineOffset + 1;
    }
  }

  return cursor > 0 ? delta : null;
}
