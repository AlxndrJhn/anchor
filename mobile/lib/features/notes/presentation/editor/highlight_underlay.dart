import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/note_typography.dart';
import '../../../../core/widgets/marker_stroke.dart';
import 'checklist_fold.dart';
import 'editor_format.dart';
import 'list_markers.dart';

class HighlightUnderlay extends CustomPainter {
  HighlightUnderlay({
    required Listenable repaint,
    required this.controller,
    required this.editor,
    required this.stack,
    required this.colors,
    required this.isDragged,
    required this.typography,
    required this.textScaler,
    this.searchTerm,
  }) : super(repaint: repaint);

  final QuillController controller;
  final RenderEditor? Function() editor;
  final RenderBox? Function() stack;
  final Color Function(String name) colors;

  final bool Function(Line line) isDragged;

  final NoteTypography typography;
  final TextScaler textScaler;

  /// The search the note was opened from, lowercase: every match is marked
  /// in yellow, like a highlight, without changing the note.
  final String? Function()? searchTerm;

  @override
  void paint(Canvas canvas, Size size) {
    final render = editor();
    final host = stack();
    if (render == null || host == null || !render.attached || !render.hasSize) {
      return;
    }
    var offset = 0;
    for (final node in controller.document.root.children) {
      _paintNode(canvas, node, render, host, offset);
      offset += node.length;
    }
  }

  void _paintNode(
    Canvas canvas,
    Node node,
    RenderEditor render,
    RenderBox host,
    int start,
  ) {
    if (node is Block) {
      var at = start;
      for (final child in node.children) {
        _paintNode(canvas, child, render, host, at);
        at += child.length;
      }
      return;
    }
    if (node is! Line || isFoldedLine(node)) return;
    final isDimmed = isDragged(node);
    final level = node.style.attributes[Attribute.header.key]?.value;
    final style = level is int ? typography.heading(level) : typography.body;
    _paintMatches(canvas, node, render, host, start, style, isDimmed);
    var at = start;
    // Runs next to each other with the same highlight are one mark.
    String? name;
    var runStart = 0;
    var runText = StringBuffer();
    void flush(int end) {
      final highlightName = name;
      if (highlightName != null && end > runStart) {
        _paintRange(
          canvas,
          render,
          host,
          runStart,
          end,
          colors(highlightName),
          '$highlightName|${_head(runText.toString())}',
          style: style,
          isDimmed: isDimmed,
        );
      }
      name = null;
      runText = StringBuffer();
    }

    for (final leaf in node.children) {
      final value = leaf.style.attributes[highlightKey]?.value;
      if (value is String && value == name) {
        runText.write(leaf.toPlainText());
      } else {
        flush(at);
        if (value is String) {
          name = value;
          runStart = at;
          runText.write(leaf.toPlainText());
        }
      }
      at += leaf.length;
    }
    flush(at);
  }

  void _paintRange(
    Canvas canvas,
    RenderEditor render,
    RenderBox host,
    int start,
    int end,
    Color fill,
    String key, {
    required TextStyle style,
    required bool isDimmed,
  }) {
    final color = isDimmed ? draggedColor(fill) : fill;
    final font = typography.font;
    final fontSize = textScaler.scale(style.fontSize!);
    final textHeight = (font.ascent + font.descent) * fontSize;
    var position = start;
    var index = 0;
    var guard = 0;
    while (position < end && guard++ < 200) {
      final line = render.getLineAtOffset(TextPosition(offset: position));
      final segmentEnd = line.end.clamp(position, end);
      if (segmentEnd <= position) break;
      final startRect = render.getLocalRectForCaret(
        TextPosition(offset: position),
      );
      final endRect = render.getLocalRectForCaret(
        TextPosition(offset: segmentEnd, affinity: TextAffinity.upstream),
      );
      final topLeft = host.globalToLocal(
        render.localToGlobal(startRect.topLeft),
      );
      final right = host
          .globalToLocal(
            render.localToGlobal(Offset(endRect.left, startRect.top)),
          )
          .dx;
      // The caret is as tall as the line, and the letters sit in its middle.
      final top = topLeft.dy + (startRect.height - textHeight) / 2;
      MarkerStroke.paint(
        canvas,
        Rect.fromLTWH(topLeft.dx, top, right - topLeft.dx, textHeight),
        color,
        key: key,
        index: index++,
        fontSize: fontSize,
      );
      position = segmentEnd;
    }
  }

  void _paintMatches(
    Canvas canvas,
    Line line,
    RenderEditor render,
    RenderBox host,
    int start,
    TextStyle style,
    bool isDimmed,
  ) {
    final term = searchTerm?.call();
    if (term == null || term.isEmpty) return;
    final text = line.toPlainText().toLowerCase();
    for (var hit = text.indexOf(term); hit != -1;) {
      _paintRange(
        canvas,
        render,
        host,
        start + hit,
        start + hit + term.length,
        colors('yellow'),
        'search|${_head(term)}',
        style: style,
        isDimmed: isDimmed,
      );
      hit = text.indexOf(term, hit + term.length);
    }
  }

  @override
  bool shouldRepaint(HighlightUnderlay old) => true;
}

/// Names a mark's stroke, so it keeps its shape between paints.
String _head(String text) => text.length > 14 ? text.substring(0, 14) : text;
