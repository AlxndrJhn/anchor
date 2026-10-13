import 'package:flutter/widgets.dart';

import 'springs.dart';

class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
    this.from = 0.92,
  });

  final Widget child;

  final Alignment alignment;

  final double from;

  @override
  Widget build(BuildContext context) {
    if (context.isMotionReduced) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: 1),
      duration: Spring.snappy.duration,
      curve: Spring.snappy.curve,
      builder: (context, scale, child) => Opacity(
        opacity: ((scale - from) / (1 - from)).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          alignment: alignment,
          child: child,
        ),
      ),
      child: child,
    );
  }
}
