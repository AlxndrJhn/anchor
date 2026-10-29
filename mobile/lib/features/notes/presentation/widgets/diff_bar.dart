import 'package:flutter/material.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../domain/note_history.dart';

/// Five small squares for the size of a change: green for what was added,
/// red for what was removed. A changed line counts as both.
class DiffBar extends StatelessWidget {
  const DiffBar(this.counts, {super.key});

  final LineCounts counts;

  static const int _squares = 5;
  static const double _square = 7; // off-scale: a mark in a row

  (int, int) get _split {
    final green = counts.added + counts.changed;
    final red = counts.removed + counts.changed;
    final total = green + red;
    if (total <= _squares) return (green, red);
    var greens = (_squares * green / total).round();
    if (green > 0 && greens == 0) greens = 1;
    if (red > 0 && greens == _squares) greens = _squares - 1;
    return (greens, _squares - greens);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final (green, red) = _split;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AnchorTokens.space2, // off-scale: between the marks
        children: [
          for (var i = 0; i < _squares; i++)
            Container(
              width: _square,
              height: _square,
              decoration: BoxDecoration(
                color: i < green
                    ? colors.statusAdded
                    : i < green + red
                    ? colors.statusRemoved
                    : colors.appText.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2), // off-scale: as above
              ),
            ),
        ],
      ),
    );
  }
}
