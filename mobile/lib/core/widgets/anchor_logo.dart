import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../theme/context_extensions.dart';

class AnchorLogo extends StatelessWidget {
  const AnchorLogo({super.key, required this.size, this.isRaised = true});

  static const double drawer = 32; // off-scale: the app's icon
  static const double about = 44; // off-scale: the app's icon
  static const double heading = 64; // off-scale: the app's icon

  final double size;

  final bool isRaised;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.25),
          boxShadow: [...colors.shadowEdge, if (isRaised) ...colors.shadowSm],
        ),
        child: CustomPaint(
          size: Size.square(size),
          painter: _LogoPainter(
            colors: context.isDark ? _LogoColors.dark : _LogoColors.light,
          ),
        ),
      ),
    );
  }
}

class _LogoColors {
  const _LogoColors({
    required this.paper,
    required this.top,
    required this.lines,
    required this.anchor,
  });

  static const light = _LogoColors(
    paper: [Color(0xFFFFFFFF), Color(0xFFE9EEF4)],
    top: [Color(0xFFF59A6C), Color(0xFFEC7743)],
    lines: Color(0xFFD5DBE4),
    anchor: Color(0xFF2D3142),
  );
  static const dark = _LogoColors(
    paper: [Color(0xFF30343F), Color(0xFF1B1D23)],
    top: [Color(0xFFEA8558), Color(0xFFD66A3A)],
    lines: Color(0xFF4A5164),
    anchor: Color(0xFFF1F4F8),
  );

  final List<Color> paper;
  final List<Color> top;
  final Color lines;
  final Color anchor;
}

/// The app icon, in its 1024 by 1024 units.
class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.colors});

  final _LogoColors colors;

  static const _topHeight = 276.0;
  static const _lines = [(392.0, 688.0), (540.0, 300.0), (688.0, 230.0)];
  static const _anchorCenter = Offset(684, 706);
  static const _anchorScale = 3.8;

  @override
  void paint(Canvas canvas, Size size) {
    Paint fade(List<Color> pair, double bottom) =>
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, bottom), pair);
    canvas
      ..save()
      ..scale(size.width / 1024)
      ..clipRRect(RRect.fromLTRBR(0, 0, 1024, 1024, const Radius.circular(256)))
      ..drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        fade(colors.paper, 1024),
      )
      ..drawRect(
        const Rect.fromLTWH(0, 0, 1024, _topHeight),
        fade(colors.top, _topHeight),
      );
    final lines = Paint()..color = colors.lines;
    for (final (top, width) in _lines) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          168,
          top,
          168 + width,
          top + 64,
          const Radius.circular(32),
        ),
        lines,
      );
    }
    final pen = Paint()
      ..color = colors.anchor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..translate(
        _anchorCenter.dx - 50 * _anchorScale,
        _anchorCenter.dy - 50 * _anchorScale,
      )
      ..scale(_anchorScale)
      ..drawCircle(const Offset(50, 18), 9, pen)
      ..drawPath(
        Path()
          ..moveTo(50, 27)
          ..lineTo(50, 94)
          ..moveTo(10, 54)
          ..arcToPoint(
            const Offset(90, 54),
            radius: const Radius.circular(40),
            clockwise: false,
          )
          ..moveTo(10, 54)
          ..lineTo(22, 54)
          ..moveTo(90, 54)
          ..lineTo(78, 54),
        pen,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.colors != colors;
}
