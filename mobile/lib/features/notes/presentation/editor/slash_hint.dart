import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'editor_format.dart';
import 'line_kind.dart';

class SlashHint extends CustomPainter {
  SlashHint({
    required this.controller,
    required this.focusNode,
    required this.editor,
    required this.stack,
    required this.style,
    required this.textScaler,
    required this.hint,
  }) : _words = TextPainter(
         text: TextSpan(text: hint, style: style),
         strutStyle: StrutStyle.fromTextStyle(style),
         textScaler: textScaler,
         textDirection: TextDirection.ltr,
         maxLines: 1,
       ),
       super(repaint: Listenable.merge([controller, focusNode]));

  final QuillController controller;
  final String hint;
  final FocusNode focusNode;
  final RenderEditor? Function() editor;
  final RenderBox? Function() stack;
  final TextStyle style;
  final TextScaler textScaler;
  final TextPainter _words;

  bool _isLaidOut = false;

  @override
  void paint(Canvas canvas, Size size) {
    final caret = controller.selection;
    if (!focusNode.hasFocus || !caret.isCollapsed) return;
    final line = controller.document.queryChild(caret.baseOffset).node;
    if (line is! Line ||
        line.length != 1 ||
        lineKindOfLine(line) != LineKind.text) {
      return;
    }
    final render = editor();
    final host = stack();
    if (render == null || host == null || !render.attached || !render.hasSize) {
      return;
    }
    final top = render.getLocalRectForCaret(caret.extent).top;
    if (!_isLaidOut) {
      _words.layout();
      _isLaidOut = true;
    }
    _words.paint(
      canvas,
      host.globalToLocal(render.localToGlobal(Offset(0, top))),
    );
  }

  void dispose() => _words.dispose();

  @override
  bool shouldRepaint(SlashHint old) =>
      old.style != style || old.textScaler != textScaler;
}
