import 'package:flutter/widgets.dart';

import '../motion/animated_resize.dart';
import '../motion/springs.dart';

class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedResize(
        duration: Spring.smooth.duration,
        curve: Spring.smooth.curve,
        alignment: Alignment.topCenter,
        child: visible
            ? child
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}
