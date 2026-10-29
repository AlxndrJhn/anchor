import 'package:flutter/material.dart';

import '../theme/context_extensions.dart';

class AnchorGlyph extends StatelessWidget {
  const AnchorGlyph({
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 2.1,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AnchorPainter(
        color ?? IconTheme.of(context).color ?? context.anchor.appText,
        strokeWidth,
      ),
    );
  }
}

class _AnchorPainter extends CustomPainter {
  _AnchorPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawCircle(const Offset(12, 5), 2.2, pen)
      ..drawPath(
        Path()
          ..moveTo(12, 7.2)
          ..lineTo(12, 21)
          ..moveTo(8, 11)
          ..lineTo(16, 11)
          ..moveTo(5, 14)
          ..arcToPoint(
            const Offset(19, 14),
            radius: const Radius.circular(7),
            clockwise: false,
          )
          ..moveTo(5, 14)
          ..relativeLineTo(-1.6, 1.6)
          ..moveTo(5, 14)
          ..relativeLineTo(1.6, 1.6)
          ..moveTo(19, 14)
          ..relativeLineTo(1.6, 1.6)
          ..moveTo(19, 14)
          ..relativeLineTo(-1.6, 1.6),
        pen,
      );
  }

  @override
  bool shouldRepaint(_AnchorPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
