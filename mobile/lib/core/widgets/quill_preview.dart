import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/context_extensions.dart';
import '../theme/tokens/app_icon_sizes.dart';
import 'editor/text_formats.dart';

/// A single line in the preview with optional list/checklist state.
class _PreviewLine {
  final String text;

  /// The line's text runs with their inline attributes.
  final List<_PreviewRun> runs;
  final String?
  listType; // 'checked' | 'unchecked' | 'ordered' | 'bullet' | null

  /// Nesting level (0 = top level).
  final int indent;

  /// The line's position in the note.
  final int index;

  const _PreviewLine({
    required this.text,
    required this.index,
    this.runs = const [],
    this.listType,
    this.indent = 0,
  });

  bool get isChecklist => listType == 'checked' || listType == 'unchecked';
  bool get isChecked => listType == 'checked';
  bool get isOrderedList => listType == 'ordered';
  bool get isBulletList => listType == 'bullet';

  /// The runs with the line's outer whitespace trimmed, as [text] is shown.
  List<_PreviewRun> get trimmedRuns {
    final result = runs.where((r) => r.text.isNotEmpty).toList();
    while (result.isNotEmpty) {
      final first = result.first;
      final t = first.text.trimLeft();
      if (t.isNotEmpty) {
        result[0] = _PreviewRun(t, first.attributes);
        break;
      }
      result.removeAt(0);
    }
    while (result.isNotEmpty) {
      final last = result.last;
      final t = last.text.trimRight();
      if (t.isNotEmpty) {
        result[result.length - 1] = _PreviewRun(t, last.attributes);
        break;
      }
      result.removeLast();
    }
    return result;
  }
}

/// A piece of a line's text with its inline attributes.
class _PreviewRun {
  final String text;
  final Map<String, dynamic>? attributes;

  const _PreviewRun(this.text, this.attributes);
}

/// The line as a span: highlight, text colour and font show as in the
/// editor, laid over [style].
TextSpan _lineSpan(_PreviewLine line, TextStyle style) {
  final runs = line.trimmedRuns;
  final hasFormats = runs.any(
    (r) =>
        r.attributes != null &&
        (r.attributes!.containsKey(TextFormats.highlightKey) ||
            r.attributes!.containsKey(TextFormats.colorKey) ||
            r.attributes!.containsKey(TextFormats.fontKey)),
  );
  if (!hasFormats) return TextSpan(text: line.text.trim(), style: style);
  return TextSpan(
    style: style,
    children: [
      for (final run in runs)
        TextSpan(
          text: run.text,
          style: inlineFormatStyle(run.attributes, textColor: style.color),
        ),
    ],
  );
}

/// The checkboxes on note cards: a fifth larger than small icons, so they are
/// easier to hit.
const double checkboxSize = AppIconSizes.sm * 1.2;

/// A lightweight read-only preview of Quill content for list views.
/// Renders checklists with checkbox icons, bullet/ordered lists with markers, and plain text.
class QuillPreview extends StatelessWidget {
  /// The content in JSON Delta format or plain text.
  final String? content;

  /// Maximum lines to show.
  final int maxLines;

  /// Text style for the preview.
  final TextStyle? style;

  /// Makes checkboxes tappable; gets the item's line in the note.
  final ValueChanged<int>? onToggleItem;

  const QuillPreview({
    super.key,
    this.content,
    this.maxLines = 6,
    this.style,
    this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    if (content == null || content!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final dims = context.dims;
    final lines = _parseQuillContentToPreviewLines(content);

    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final effectiveStyle =
        style ??
        theme.textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          height: 1.5,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
        );

    final displayLines = lines
        .where((l) => l.text.trim().isNotEmpty)
        .take(maxLines)
        .toList();

    final orderedMarkers = OrderedMarkerCounter();
    final children = <Widget>[];

    for (final line in displayLines) {
      final marker = orderedMarkers.markerFor(
        listType: line.listType,
        indent: line.indent,
      );

      if (line.isChecklist) {
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: 2, left: line.indent * 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tappable(
                  line,
                  Padding(
                    padding: EdgeInsets.only(right: dims.xs, top: 2),
                    child: Icon(
                      line.isChecked
                          ? LucideIcons.checkSquare
                          : LucideIcons.square,
                      size: checkboxSize,
                      color: line.isChecked
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyMedium?.color?.withValues(
                              alpha: 0.6,
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _lineSpan(
                      line,
                      effectiveStyle.copyWith(
                        decoration: line.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        color: line.isChecked
                            ? theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: 0.6,
                              )
                            : null,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.isOrderedList) {
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: 2, left: line.indent * 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    marker!,
                    style: effectiveStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: dims.xxs),
                Expanded(
                  child: Text.rich(
                    _lineSpan(line, effectiveStyle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.isBulletList) {
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: 2, left: line.indent * 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: dims.xs, top: 2),
                  child: Text('•', style: effectiveStyle),
                ),
                Expanded(
                  child: Text.rich(
                    _lineSpan(line, effectiveStyle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: 2, left: line.indent * 12.0),
            child: Text.rich(
              _lineSpan(line, effectiveStyle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

extension on QuillPreview {
  /// The checkbox, tappable when items can be ticked from the card.
  Widget _tappable(_PreviewLine line, Widget box) {
    final onToggle = onToggleItem;
    if (onToggle == null) return box;
    return Semantics(
      button: true,
      checked: line.isChecked,
      label: '${line.isChecked ? 'Untick' : 'Tick'} ${line.text.trim()}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggle(line.index),
        child: box,
      ),
    );
  }
}

/// Numbering state for ordered list lines. Feed every line through in order:
/// deeper levels reset when the list returns to a shallower one, and a
/// level's own count continues across nested runs, matching the editor.
class OrderedMarkerCounter {
  final _countByLevel = <int, int>{};

  /// The marker for an ordered line, null for any other.
  String? markerFor({required String? listType, required int indent}) {
    if (listType == null) {
      _countByLevel.clear();
      return null;
    }
    _countByLevel.removeWhere((level, _) => level > indent);
    if (listType != 'ordered') return null;

    final count = (_countByLevel[indent] ?? 0) + 1;
    _countByLevel[indent] = count;
    return orderedListMarker(count, indent);
  }
}

/// Marker for an ordered item, cycling number styles by depth like the
/// editor: 1. at the top level, then a., then i.
String orderedListMarker(int count, int indent) {
  return switch (indent % 3) {
    1 => '${_alpha(count)}.',
    2 => '${_roman(count)}.',
    _ => '$count.',
  };
}

String _alpha(int count) => String.fromCharCode(97 + (count - 1) % 26);

String _roman(int count) {
  const pairs = [
    (1000, 'm'),
    (900, 'cm'),
    (500, 'd'),
    (400, 'cd'),
    (100, 'c'),
    (90, 'xc'),
    (50, 'l'),
    (40, 'xl'),
    (10, 'x'),
    (9, 'ix'),
    (5, 'v'),
    (4, 'iv'),
    (1, 'i'),
  ];
  var value = count;
  final buffer = StringBuffer();
  for (final (threshold, numeral) in pairs) {
    while (value >= threshold) {
      buffer.write(numeral);
      value -= threshold;
    }
  }
  return buffer.toString();
}

/// Parses Quill Delta JSON into preview lines with checklist state.
/// Returns empty list if content is null/empty/invalid.
List<_PreviewLine> _parseQuillContentToPreviewLines(String? content) {
  if (content == null || content.isEmpty) return [];
  try {
    final json = jsonDecode(content);
    if (json is! Map || json['ops'] is! List) return [];
    final document = Document.fromJson(json['ops'] as List);
    final ops = document.toDelta().toList();
    final result = <_PreviewLine>[];
    var currentRuns = <_PreviewRun>[];
    // A line holding only a picture placed in the text shows nothing here,
    // but still counts: a line's index is where it is in the note.
    var isEmbedLine = false;
    var lineCount = 0;

    for (final op in ops) {
      if (op.data is! String) {
        currentRuns.add(const _PreviewRun('', null));
        isEmbedLine = true;
        continue;
      }
      final text = op.data as String;
      final parts = text.split('\n');

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isNotEmpty) {
          currentRuns.add(_PreviewRun(part, op.attributes));
        }
        if (i < parts.length - 1) {
          final listType = op.attributes?['list'] as String?;
          final indent = op.attributes?['indent'] as int? ?? 0;
          final lineText = currentRuns.map((r) => r.text).join();
          final index = lineCount++;
          if (isEmbedLine && lineText.isEmpty) {
            currentRuns = [];
            isEmbedLine = false;
            continue;
          }
          isEmbedLine = false;
          result.add(
            _PreviewLine(
              text: lineText,
              runs: currentRuns,
              index: index,
              listType: listType,
              indent: indent,
            ),
          );
          currentRuns = [];
        }
      }
    }

    if (currentRuns.isNotEmpty) {
      result.add(
        _PreviewLine(
          text: currentRuns.map((r) => r.text).join(),
          runs: currentRuns,
          index: lineCount,
        ),
      );
    }

    return result;
  } catch (_) {
    return [];
  }
}

/// Extracts plain text from canonical Quill Delta JSON (`{ops: [...]}`).
/// Strict: returns empty string if the content is null/empty/invalid.
String extractPlainTextFromQuillContent(String? content) {
  if (content == null || content.isEmpty) return '';
  try {
    final json = jsonDecode(content);
    if (json is Map && json['ops'] is List) {
      final document = Document.fromJson(json['ops'] as List);
      // Embeds (pictures in the text) come out as U+FFFC.
      final raw = document.toPlainText().replaceAll('\uFFFC', '');
      final lines = raw
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      // Preserve real newlines, but ignore multiple blank newlines.
      return lines.join('\n');
    }
  } catch (_) {
    // invalid JSON -> strict mode
  }
  return '';
}
