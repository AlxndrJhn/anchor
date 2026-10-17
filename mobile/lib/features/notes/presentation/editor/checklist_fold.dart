import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';

/// Equal to [Attribute.checked]: the document and its delta never see it.
class FoldedCheckedAttribute extends ListAttribute {
  const FoldedCheckedAttribute() : super('checked');
}

const foldedTextStyle = TextStyle(
  fontSize: 0.01, // off-scale: a folded line takes no room
  height: 1,
  color: Color(0x00000000),
  decoration: TextDecoration.none,
);

bool isFoldedLine(Line line) =>
    line.style.attributes[Attribute.list.key] is FoldedCheckedAttribute;

class ListLine {
  const ListLine({this.endsList = false, this.checkedBelow = 0});

  final bool endsList;

  /// Set on the first of a checklist's trailing checked items, to their count.
  final int checkedBelow;
}

class ListLines {
  ListLines._(this._lines, this.folded);

  static final empty = ListLines._(HashMap.identity(), const []);

  /// Tags the folded lines.
  factory ListLines.of(
    Document document, {
    required bool canFold,
    required bool isFolded,
  }) {
    final all = <Line>[];
    for (final node in document.root.children) {
      if (node is Line) {
        all.add(node);
      } else if (node is Block) {
        for (final line in node.children) {
          if (line is Line) all.add(line);
        }
      }
    }
    final lines = HashMap<Line, ListLine>.identity();
    final folded = <TextRange>[];
    var i = 0;
    while (i < all.length) {
      final kind = _kindOf(all[i]);
      if (kind == null) {
        i++;
        continue;
      }
      var end = i;
      while (end + 1 < all.length && _kindOf(all[end + 1]) == kind) {
        end++;
      }
      var head = end + 1;
      if (canFold && kind == _ListKind.checklist) {
        while (head > i && _isChecked(all[head - 1])) {
          head--;
        }
      }
      for (var k = i; k <= end; k++) {
        lines[all[k]] = ListLine(
          endsList: k == end,
          checkedBelow: k == head ? end - head + 1 : 0,
        );
        if (kind == _ListKind.checklist) {
          _tag(all[k], isFolded: isFolded && k >= head);
        }
      }
      if (isFolded && head <= end) {
        final last = all[end];
        folded.add(
          TextRange(
            start: all[head].documentOffset,
            end: last.documentOffset + last.length - 1,
          ),
        );
      }
      i = end + 1;
    }
    return ListLines._(lines, folded);
  }

  final Map<Line, ListLine> _lines;

  /// Each from its first item's start to its last item's line break.
  final List<TextRange> folded;

  ListLine? operator [](Line line) => _lines[line];

  bool isFolded(int offset) =>
      folded.any((range) => offset >= range.start && offset <= range.end);

  static void _tag(Line line, {required bool isFolded}) {
    if (isFoldedLine(line) == isFolded) return;
    if (isFolded) {
      line.applyAttribute(const FoldedCheckedAttribute());
    } else if (_isChecked(line)) {
      line.applyAttribute(Attribute.checked);
    }
  }
}

enum _ListKind { checklist, bullet, numbered }

_ListKind? _kindOf(Line line) =>
    switch (line.style.attributes[Attribute.list.key]?.value) {
      'checked' || 'unchecked' => _ListKind.checklist,
      'bullet' => _ListKind.bullet,
      'ordered' => _ListKind.numbered,
      _ => null,
    };

bool _isChecked(Line line) =>
    line.style.attributes[Attribute.list.key]?.value == 'checked';

class CheckedFoldRow extends StatelessWidget {
  const CheckedFoldRow({
    super.key,
    required this.count,
    required this.isFolded,
    required this.color,
    required this.onTap,
  });

  final int count;
  final bool isFolded;
  final Color color;
  final VoidCallback onTap;

  static String labelOf(int count, AppLocalizations l10n) =>
      l10n.editorCheckedItems(count);

  @override
  Widget build(BuildContext context) {
    final spring = Spring.snappy;
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: {
        // Holding the row would select the text under it.
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              LongPressGestureRecognizer.new,
              (recognizer) => recognizer.onLongPress = () {},
            ),
      },
      child: Pressable(
        style: PressStyle.plain,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: Semantics(
          expanded: !isFolded,
          child: SizedBox(
            height: AnchorTokens.sizeControlMedium,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: AnchorTokens.space32,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      // off-scale: centers the chevron over the checkboxes
                      child: AnimatedRotation(
                        turns: isFolded ? -0.25 : 0,
                        duration: context.motion(spring.duration),
                        curve: spring.curve,
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: AnchorTokens.sizeIconSmall,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  labelOf(count, context.l10n),
                  maxLines: 1,
                  style: AppTypography.secondary.copyWith(
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
