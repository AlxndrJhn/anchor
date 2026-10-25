import 'package:flutter/widgets.dart';

import '../theme/context_extensions.dart';
import '../theme/tokens/app_style.dart';

/// The style's page texture over [child]: linen for Skeuomorphism, a dot grid
/// for Lo-fi, nothing otherwise.
class StyleTexture extends StatelessWidget {
  const StyleTexture({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = context.appStyle;
    final color = style.pattern;
    if (color == null) return child;
    return CustomPaint(
      isComplex: true,
      willChange: false,
      foregroundPainter: style.style == AppStyle.lofi
          ? _DotGridPainter(color)
          : _LinenPainter(color),
      child: child,
    );
  }
}

/// Two fine cross weaves, as on the web.
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

/// A dot every 18 points, as on the web.
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
