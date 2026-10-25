import 'package:flutter/material.dart';

import '../theme/context_extensions.dart';
import '../theme/tokens/app_opacity.dart';
import '../theme/tokens/app_style.dart';

/// Which full-screen wash a page sits on.
enum PageWash {
  gradient,
  content;

  Widget wrap(Widget child) => switch (this) {
    PageWash.gradient => GradientBackground(child: child),
    PageWash.content => ContentBackground(child: child),
  };
}

/// Full-screen wash behind screens whose cards are glassy and translucent —
/// settings, auth, the drawer, note history.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: context.colorTokens.pageGradient),
      child: StyleTexture(child: child),
    );
  }
}

/// Full-screen wash behind screens that list opaque note cards. Flatter and a
/// shade darker than [GradientBackground] so the cards read as raised.
class ContentBackground extends StatelessWidget {
  const ContentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHighest.withValues(
              alpha: AppOpacity.border,
            ),
          ],
        ),
      ),
      child: StyleTexture(child: child),
    );
  }
}

/// The style's page texture behind [child]: linen for Skeuomorphism, a dot
/// grid for Lo-fi, nothing otherwise.
class StyleTexture extends StatelessWidget {
  const StyleTexture({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = context.styleTokens;
    final color = style.pattern;
    if (color == null) return child;
    return CustomPaint(
      isComplex: true,
      painter: style.style == AppStyle.lofi
          ? _DotGridPainter(color)
          : _LinenPainter(color),
      child: child,
    );
  }
}

class _LinenPainter extends CustomPainter {
  _LinenPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 0.5; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    paint.color = color.withValues(alpha: color.a * 0.6);
    for (var x = 0.5; x < size.width; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_LinenPainter old) => old.color != color;
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 9.0; y < size.height; y += 18) {
      for (var x = 9.0; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
