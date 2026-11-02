import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/note_typography.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/move_actions.dart';
import '../../../../l10n/l10n.dart';
import 'checklist_drag_controller.dart';
import 'checklist_fold.dart';
import 'document_lines.dart';
import 'editor_palette.dart';
import 'list_line.dart';

extension ListSpacing on NoteTypography {
  double get listLinePadding => bodySize * 0.1;

  double get listEndGap => bodySize * 0.75;
}

const double _checkboxInset = 2; // off-scale: the checkbox column

const double _checkboxSize = 22; // off-scale: the note's checkbox

/// Quill rebuilds every line on each change; an identical widget skips it.
class ListMarkerCache {
  final Expando<(Object, Widget)> _markers = Expando();
  final Expando<(Object, Widget)> _rows = Expando();

  Widget _cached(
    Expando<(Object, Widget)> cache,
    Line line,
    Object key,
    Widget Function() build,
  ) {
    final cached = cache[line];
    if (cached != null && cached.$1 == key) return cached.$2;
    final widget = build();
    cache[line] = (key, widget);
    return widget;
  }
}

/// Null for a line that isn't a list or code.
Widget? buildListMarker(
  BuildContext context,
  Line line,
  LeadingConfig config, {
  required ListMarkerCache cache,
  required ListLine? role,
  required EditorPalette palette,
  required bool canEdit,
  required ChecklistDragController drag,
  required void Function(Line line, bool checked) onToggle,
  required bool Function(Line line) wasJustChecked,
  required bool isFolded,
  required VoidCallback onFold,
  required bool isDragged,
}) {
  if (config.attrs.containsKey(Attribute.codeBlock.key)) {
    return const SizedBox.shrink();
  }
  final level = config.attrs.indentLevel;
  final typography = context.noteTypography;
  final listLinePadding = typography.listLinePadding;
  final fontSize = MediaQuery.textScalerOf(context).scale(typography.bodySize);
  final lineHeight = fontSize * typography.lineHeight;
  final left = level * AnchorTokens.sizeListIndent;
  final muted = palette.muted;
  final endGap = role?.endsList ?? false ? typography.listEndGap : 0.0;
  final checkedBelow = role?.checkedBelow ?? 0;
  final foldGap = checkedBelow > 0 ? AnchorTokens.sizeControlMedium : 0.0;
  final row = checkedBelow > 0
      ? cache._cached(
          cache._rows,
          line,
          (checkedBelow, isFolded, muted),
          () => CheckedFoldRow(
            count: checkedBelow,
            isFolded: isFolded,
            color: muted,
            onTap: onFold,
          ),
        )
      : null;

  // Equal to Quill's own spacing, which it sets again on every change. A list
  // block holds the space at its ends, an indented one doesn't.
  final block = line.parent;
  final hasEnds =
      block is Block && !block.style.containsKey(Attribute.indent.key);
  final above = hasEnds && line.isFirst ? 0.0 : listLinePadding;
  final below = hasEnds && line.isLast ? 0.0 : listLinePadding;

  if (isFoldedLine(line)) {
    final top = math.max(0.0, foldGap - listLinePadding + above);
    return ListLineLeading(
      top: top,
      bottom: math.max(0.0, endGap - listLinePadding + below),
      marker: const SizedBox.shrink(),
      row: row,
      rowHeight: foldGap,
      rowAbove: top + listLinePadding - above,
    );
  }

  final top = above + foldGap;
  final bottom = below + endGap;
  final rowAbove = listLinePadding + foldGap;
  final guide = palette.border.withValues(alpha: palette.border.a * 0.85);
  if (config.attrs.isChecklist) {
    final enabled = (config.enabled ?? true) && canEdit;
    final boxLeft = left + _checkboxInset;
    final targetLeft = math.max(
      0.0,
      boxLeft + (_checkboxSize - AnchorTokens.sizeControlMedium) / 2,
    );
    final targetHeight = lineHeight + 2 * listLinePadding;
    final boxTop = listLinePadding + (lineHeight - _checkboxSize) / 2;
    final text = line.toPlainText();
    final label = text.length > 1 ? text.substring(0, text.length - 1) : '';
    final checked = config.value;
    final isJustChecked = wasJustChecked(line);
    final moves = enabled ? _checklistMovesOf(line) : _noMoves;
    final tick = context.anchor.checkMark == context.anchor.appSurface
        ? palette.background
        : context.anchor.checkMark;
    return ListLineLeading(
      top: top,
      bottom: bottom,
      guides: level,
      guideColor: guide,
      guideReach: listLinePadding,
      markerRect: Rect.fromLTWH(
        targetLeft,
        -listLinePadding,
        AnchorTokens.sizeControlMedium,
        targetHeight,
      ),
      row: row,
      rowHeight: foldGap,
      rowAbove: rowAbove,
      marker: cache._cached(
        cache._markers,
        line,
        (
          checked,
          label,
          enabled,
          boxLeft - targetLeft,
          boxTop,
          isJustChecked,
          muted,
          tick,
          isDragged,
          moves,
        ),
        () => _CheckboxTarget(
          checked: checked,
          label: label,
          enabled: enabled,
          onToggle: () => onToggle(line, !checked),
          moves: moves,
          drag: drag,
          line: line,
          child: Padding(
            padding: EdgeInsets.only(left: boxLeft - targetLeft, top: boxTop),
            child: Align(
              alignment: Alignment.topLeft,
              child: NoteCheckBox(
                checked: checked,
                isJustChecked: isJustChecked,
                border: muted,
                opacity: isDragged ? _draggedOpacity : 1,
                tick: tick,
              ),
            ),
          ),
        ),
      ),
    );
  }

  final Widget Function() marker;
  final Object key;
  if (config.attribute == Attribute.ol) {
    final number = '${config.getIndexNumberByIndent ?? config.index ?? 1}.';
    final style = typography.listNumber.copyWith(color: muted);
    key = (number, left, lineHeight, style);
    marker = () => Padding(
      padding: EdgeInsets.only(left: left),
      child: SizedBox(
        width: 22, // off-scale: list marker column
        height: lineHeight,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 3), // off-scale: list number
            child: Text(
              number,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: style,
            ),
          ),
        ),
      ),
    );
  } else if (config.attribute == Attribute.ul) {
    key = (level, left, lineHeight, muted);
    marker = () => Padding(
      padding: EdgeInsets.only(left: left),
      child: SizedBox(
        width: 22, // off-scale: list marker column
        height: lineHeight,
        child: Center(
          child: ListBullet(level: level, color: muted),
        ),
      ),
    );
  } else {
    return null;
  }
  return ListLineLeading(
    top: top,
    bottom: bottom,
    guides: level,
    guideColor: guide,
    guideReach: listLinePadding,
    marker: cache._cached(
      cache._markers,
      line,
      key,
      () => Align(alignment: Alignment.topLeft, child: marker()),
    ),
  );
}

/// How many items at [line]'s level, under the same parent, are shown
/// above it and below it, counting to two: enough to tell which moves go
/// somewhere. Quick, as it's worked out for each line as it's drawn.
typedef _ChecklistMoves = ({int above, int below});

const _ChecklistMoves _noMoves = (above: 0, below: 0);

_ChecklistMoves _checklistMovesOf(Line line) {
  final indent = line.style.attributes.indentLevel;
  int count(Line? Function(Line) step) {
    var count = 0;
    for (
      var other = step(line);
      other != null && count < 2;
      other = step(other)
    ) {
      final attributes = other.style.attributes;
      if (!attributes.isChecklist || attributes.indentLevel < indent) break;
      if (attributes.indentLevel == indent && !isFoldedLine(other)) count++;
    }
    return count;
  }

  return (above: count(_lineBefore), below: count((l) => l.nextLine));
}

Line? _lineBefore(Line line) {
  final before =
      line.previous ?? (line.parent is Block ? line.parent!.previous : null);
  return switch (before) {
    final Block block => block.last as Line?,
    final Line other => other,
    _ => null,
  };
}

const double _draggedOpacity = 0.35;

Color draggedColor(Color color) =>
    color.withValues(alpha: color.a * _draggedOpacity);

class _CheckboxTarget extends StatelessWidget {
  const _CheckboxTarget({
    required this.checked,
    required this.label,
    required this.enabled,
    required this.onToggle,
    required this.moves,
    required this.drag,
    required this.line,
    required this.child,
  });

  final bool checked;
  final String label;
  final bool enabled;
  final VoidCallback onToggle;
  final _ChecklistMoves moves;
  final ChecklistDragController drag;
  final Line line;
  final Widget child;

  void _move(ChecklistMove move) => drag.move(line.documentOffset, move);

  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    enabled: enabled,
    label: label.isEmpty ? context.l10n.editorEmptyItem : label,
    onTap: enabled ? onToggle : null,
    // Held and dragged otherwise.
    customSemanticsActions: moveActions(
      context,
      up: moves.above > 0 ? () => _move(ChecklistMove.up) : null,
      down: moves.below > 0 ? () => _move(ChecklistMove.down) : null,
      top: moves.above > 1 ? () => _move(ChecklistMove.top) : null,
      bottom: moves.below > 1 ? () => _move(ChecklistMove.bottom) : null,
    ),
    child: RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      gestures: enabled
          ? {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (recognizer) => recognizer.onTap = onToggle,
                  ),
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(
                      duration: AnchorTokens.motionDurationLongPress,
                    ),
                    (recognizer) => recognizer
                      ..onLongPressStart = ((details) =>
                          drag.start(line.documentOffset, details))
                      ..onLongPressMoveUpdate = drag.update
                      ..onLongPressEnd = ((_) => drag.end())
                      ..onLongPressCancel = drag.cancel,
                  ),
            }
          : const {},
      child: child,
    ),
  );
}

class ListBullet extends StatelessWidget {
  const ListBullet({super.key, required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) => switch (level % 3) {
    0 => Container(
      width: 6, // off-scale: bullet
      height: 6, // off-scale: bullet
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
    1 => Container(
      width: 6, // off-scale: bullet
      height: 6, // off-scale: bullet
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    ),
    _ => Container(
      width: 7, // off-scale: bullet
      height: 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1), // off-scale: bullet
      ),
    ),
  };
}

class NoteCheckBox extends StatelessWidget {
  const NoteCheckBox({
    super.key,
    required this.checked,
    this.isJustChecked = false,
    required this.border,
    this.opacity = 1,
    required this.tick,
  });

  final bool checked;
  final bool isJustChecked;
  final Color border;
  final double opacity;
  final Color tick;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    Widget mark = Icon(
      LucideIcons600.check,
      size: 15, // off-scale: the note's check mark
      color: tick,
    );
    if (isJustChecked && !context.isMotionReduced) {
      mark = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AnchorTokens.motionDurationTick,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.2 + 0.8 * AnchorTokens.motionEasePop.transform(t),
            child: child,
          ),
        ),
        child: mark,
      );
    }
    return Opacity(
      opacity: opacity,
      child: AnimatedContainer(
        duration: context.motion(AnchorTokens.motionDurationHover),
        width: _checkboxSize,
        height: _checkboxSize,
        decoration: BoxDecoration(
          color: checked ? colors.accentStrong : null,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusCheckbox),
          border: Border.all(
            color: checked ? colors.accentStrong : border,
            width: 1.5,
          ),
        ),
        child: checked ? mark : null,
      ),
    );
  }
}
