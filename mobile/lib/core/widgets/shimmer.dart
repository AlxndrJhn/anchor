import 'package:flutter/widgets.dart';

import '../motion/springs.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';

/// Paints [child]'s shapes in [color], whatever color they are drawn in.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.color, this.child = _fill});

  static const Widget _fill = SizedBox.expand(
    child: ColoredBox(color: Color(0xFF000000)),
  );

  final Color color;
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: AnchorTokens.motionDurationShimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.isMotionReduced) {
      _run.stop();
    } else if (!_run.isAnimating) {
      _run.repeat();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final light = Color.lerp(color, context.anchor.appSurface, 0.6)!;
    final isStill = context.isMotionReduced;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _run,
        child: widget.child,
        builder: (context, child) {
          final sweep = 3 * _run.value;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(sweep - 2, 0),
              end: Alignment(sweep, 0),
              colors: isStill ? [color, color] : [color, light, color],
            ).createShader(bounds),
            child: child,
          );
        },
      ),
    );
  }
}
