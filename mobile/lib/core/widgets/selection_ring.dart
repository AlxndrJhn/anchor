import 'package:flutter/widgets.dart';

import '../motion/springs.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';

/// A ring a little outside [child] while [isShown]: a gap in the color behind
/// it, then the ring.
///
/// Both grow [borderRadius] outwards with them, as CSS does with a spread
/// shadow, so they keep their width around the corners. A spread [BoxShadow]
/// keeps the child's radius and gets wider there.
class SelectionRing extends StatelessWidget {
  const SelectionRing({
    super.key,
    required this.isShown,
    required this.borderRadius,
    required this.child,
    this.gap,
    this.color,
  });

  static const double gapWidth = 2;
  static const double width = 2;

  final bool isShown;
  final BorderRadius borderRadius;

  /// The color behind [child]; the surface when null.
  final Color? gap;
  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: isShown ? 1 : 0),
      duration: context.motion(AnchorTokens.motionDurationFade),
      curve: AnchorTokens.motionEaseStandard,
      builder: (context, shown, child) => CustomPaint(
        painter: shown == 0
            ? null
            : _RingPainter(
                shown: shown,
                borderRadius: borderRadius,
                gap: gap ?? colors.appSurface,
                color: color ?? colors.accentStrong,
              ),
        child: child,
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.shown,
    required this.borderRadius,
    required this.gap,
    required this.color,
  });

  final double shown;
  final BorderRadius borderRadius;
  final Color gap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Filled shapes under the child rather than bands, so no edge falls
    // between two antialiased edges.
    final gapEdge = borderRadius
        .toRRect(Offset.zero & size)
        .inflate(SelectionRing.gapWidth);
    canvas
      ..drawRRect(
        gapEdge.inflate(SelectionRing.width),
        Paint()..color = color.withValues(alpha: color.a * shown),
      )
      ..drawRRect(
        gapEdge,
        Paint()..color = gap.withValues(alpha: gap.a * shown),
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.shown != shown ||
      old.borderRadius != borderRadius ||
      old.gap != gap ||
      old.color != color;
}
