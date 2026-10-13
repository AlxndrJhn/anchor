import 'package:flutter/widgets.dart';

import 'springs.dart';

class AnimatedResize extends StatelessWidget {
  const AnimatedResize({
    super.key,
    required this.duration,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Clip clipBehavior;
  final Widget child;

  // AnimatedSize throws when given a zero duration.
  static const Duration _shortest = Duration(microseconds: 1);

  @override
  Widget build(BuildContext context) {
    final wanted = context.motion(duration);
    return AnimatedSize(
      duration: wanted < _shortest ? _shortest : wanted,
      curve: curve,
      alignment: alignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
