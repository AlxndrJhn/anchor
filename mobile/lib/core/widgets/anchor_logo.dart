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
    required this.anchor,
    required this.plus,
  });

  static const light = _LogoColors(
    sea: [Color(0xFF13687A), Color(0xFF0B3B4A)],
    anchor: Color(0xFFF4F1E8),
    plus: Color(0xFFF2B544),
  );
  static const dark = _LogoColors(
    sea: [Color(0xFF0F4F5E), Color(0xFF06222B)],
    anchor: Color(0xFFE9ECE8),
    plus: Color(0xFFF2B544),
  );

  final List<Color> sea;
  final Color anchor;
  final Color plus;
}

/// The app icon, in its 1024 by 1024 units: tool/launcher_icon/icon.js's.
class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.colors});

  final _LogoColors colors;

  static const _stroke = 72.0;

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
      // The shank, the arms around its foot and their flukes.
      ..drawPath(
        Path()
          ..moveTo(512, 428)
          ..lineTo(512, 788)
          ..moveTo(272, 548)
          ..arcToPoint(
            const Offset(752, 548),
            radius: const Radius.circular(240),
            clockwise: false,
          )
          ..moveTo(272, 548)
          ..lineTo(344, 548)
          ..moveTo(752, 548)
          ..lineTo(680, 548),
        pen(colors.anchor),
      )
      // The + of Anchor+, the anchor's ring.
      ..drawPath(
        Path()
          ..moveTo(512, 236)
          ..lineTo(512, 404)
          ..moveTo(428, 320)
          ..lineTo(596, 320),
        pen(colors.plus),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.colors != colors;
}
