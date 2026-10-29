import 'package:flutter/material.dart';

import '../motion/springs.dart';
import '../theme/tokens/anchor_tokens.dart';

class RollingText extends StatelessWidget {
  const RollingText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(text);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: context.motion(Spring.snappy.duration),
        switchInCurve: Spring.snappy.curve,
        switchOutCurve: AnchorTokens.motionEaseExit,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == key;
          return SlideTransition(
            position: Tween(
              begin: Offset(0, isIncoming ? 1 : -1),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: SizedBox(
          key: key,
          width: double.infinity,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          ),
        ),
      ),
    );
  }
}
