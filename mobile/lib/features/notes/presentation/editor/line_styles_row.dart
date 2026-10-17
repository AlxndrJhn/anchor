import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import 'editor_tool_button.dart';
import 'editor_toolbar_mode.dart';
import 'line_kind.dart';

class LineStylesRow extends StatelessWidget {
  const LineStylesRow({
    super.key,
    required this.lineKind,
    required this.slotWidth,
    required this.onPick,
  });

  final LineKind lineKind;
  final double slotWidth;
  final ValueChanged<LineKind> onPick;

  static IconData iconOf(LineKind kind) =>
      kind == LineKind.quote ? LucideIcons.textQuote : kind.icon;

  @override
  Widget build(BuildContext context) {
    final row = Semantics(
      container: true,
      label: context.l10n.barLineStyles,
      child: Row(
        children: [
          for (final kind in lineStyles)
            EditorToolButton(
              key: ValueKey(kind),
              icon: iconOf(kind),
              label: kind.labelIn(context.l10n),
              isOn: kind == lineKind,
              width: slotWidth,
              onPressed: () => onPick(kind),
            ),
        ],
      ),
    );
    if (context.isMotionReduced) return row;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Spring.snappy.duration,
      curve: Spring.snappy.curve,
      builder: (context, shown, child) => Opacity(
        opacity: shown.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, AnchorTokens.space8 * (1 - shown)),
          child: child,
        ),
      ),
      child: row,
    );
  }
}
