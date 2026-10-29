import 'package:flutter/widgets.dart';

class EditorPalette {
  const EditorPalette({
    required this.muted,
    required this.surface,
    required this.border,
    required this.background,
    required this.highlightFill,
    required this.highlightInk,
  });

  final Color muted;
  final Color surface;
  final Color border;
  final Color background;

  final Color Function(String name) highlightFill;

  final Color Function(String name) highlightInk;
}
