import 'dart:math' as math;
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
    required this.sea,
    required this.card,
    required this.line,
    required this.anchor,
    required this.plus,
  });

  static const light = _LogoColors(
    sea: [Color(0xFF13687A), Color(0xFF0B3B4A)],
    card: Color(0xFFF4F1E8),
    line: Color(0xFFCFD8D6),
    anchor: Color(0xFF0B3B4A),
    plus: Color(0xFFD9961C),
  );
  static const dark = _LogoColors(
    sea: [Color(0xFF0F4F5E), Color(0xFF06222B)],
    card: Color(0xFFDFE3DF),
    line: Color(0xFFBCC6C4),
    anchor: Color(0xFF0B3B4A),
    plus: Color(0xFFD9961C),
  );

  final List<Color> sea;
  final Color card;
  final Color line;
  final Color anchor;
  final Color plus;
}

/// The app icon, in its 1024 by 1024 units: tool/launcher_icon/icon.js's.
class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.colors});

  final _LogoColors colors;

  // The card and everything on it turn 6 degrees left around this point.
  static const _tiltCenter = Offset(512, 520);
  static const _tilt = -6 * math.pi / 180;
  static const _stroke = 47.5;

  @override
  void paint(Canvas canvas, Size size) {
    Paint pen(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..save()
      ..scale(size.width / 1024)
      ..clipRRect(RRect.fromLTRBR(0, 0, 1024, 1024, const Radius.circular(256)))
      ..drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(1024, 1024),
            colors.sea,
          ),
      )
      ..translate(_tiltCenter.dx, _tiltCenter.dy)
      ..rotate(_tilt)
      ..translate(-_tiltCenter.dx, -_tiltCenter.dy)
      ..drawRRect(
        RRect.fromLTRBR(196, 150, 828, 890, const Radius.circular(80)),
        Paint()..color = colors.card,
      )
      // The card's title line.
      ..drawRRect(
        RRect.fromLTRBR(290, 236, 590, 280, const Radius.circular(22)),
        Paint()..color = colors.line,
      )
      // The shank, the arms around its foot and their flukes.
      ..drawPath(
        Path()
          ..moveTo(512, 534.6)
          ..lineTo(512, 772.2)
          ..moveTo(353.6, 613.8)
          ..arcToPoint(
            const Offset(670.4, 613.8),
            radius: const Radius.circular(158.4),
            clockwise: false,
          )
          ..moveTo(353.6, 613.8)
          ..lineTo(401.1, 613.8)
          ..moveTo(670.4, 613.8)
          ..lineTo(622.9, 613.8),
        pen(colors.anchor),
      )
      // The + of Anchor+, the anchor's ring.
      ..drawPath(
        Path()
          ..moveTo(512, 407.8)
          ..lineTo(512, 518.7)
          ..moveTo(456.6, 463.3)
          ..lineTo(567.4, 463.3),
        pen(colors.plus),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.colors != colors;
}
