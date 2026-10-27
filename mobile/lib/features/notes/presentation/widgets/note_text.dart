import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/widgets/highlighted_text.dart';
import '../../domain/note_blocks.dart';
import '../editor/text_formats.dart';
import 'note_surface.dart';

/// Runs of a line as one span, with their highlights as [HighlightRange]s.
(InlineSpan, List<HighlightRange>) spanOfRuns(
  BuildContext context,
  List<InlineRun> runs, {
  required TextStyle style,
  required NoteAppearance appearance,
  bool isStrikethrough = false,
}) {
  final colors = context.anchor;
  final children = <InlineSpan>[];
  final highlights = <HighlightRange>[];
  var offset = 0;
  final text = style.color ?? colors.appText;
  for (final run in runs) {
    // An explicit color wins; on a custom highlight, ink that reads on it.
    final custom = run.highlight != null && isCustomHighlight(run.highlight)
        ? appearance.highlight(context, run.highlight!)
        : null;
    final color =
        textColorOf(run.color) ??
        (custom == null ? null : customHighlightInk(custom, text));
    final family = TextFont.of(run.font)?.family;
    final decorations = <TextDecoration>[
      if (run.underline || run.link != null) TextDecoration.underline,
      if (run.strike || isStrikethrough) TextDecoration.lineThrough,
    ];
    children.add(
      TextSpan(
        text: run.text,
        style: TextStyle(
          fontWeight: run.bold ? FontWeight.w700 : null,
          fontStyle: run.italic ? FontStyle.italic : null,
          decoration: decorations.isEmpty
              ? null
              : TextDecoration.combine(decorations),
          decorationColor: run.link != null
              ? colors.accentInk.withValues(alpha: 0.5)
              : null,
          color: run.link != null ? colors.accentInk : color,
          fontFamily: run.code ? AppTypography.mono : family,
          fontSize: run.code ? (style.fontSize ?? 14) * 0.9 : null,
          backgroundColor: run.code ? appearance.colors.surface : null,
        ),
      ),
    );
    if (run.highlight != null) {
      final start = offset;
      final end = offset + run.text.length;
      final previous = highlights.isNotEmpty ? highlights.last : null;
      if (previous != null &&
          previous.end == start &&
          previous.key.startsWith('${run.highlight}|')) {
        highlights[highlights.length - 1] = HighlightRange(
          start: previous.start,
          end: end,
          color: previous.color,
          key: previous.key,
        );
      } else {
        highlights.add(
          HighlightRange(
            start: start,
            end: end,
            color: appearance.highlight(context, run.highlight!),
            key:
                '${run.highlight}|${run.text.length > 14 ? run.text.substring(0, 14) : run.text}',
          ),
        );
      }
    }
    offset += run.text.length;
  }
  return (TextSpan(style: style, children: children), highlights);
}
