import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/motion/springs.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';

class HarborIllustration extends StatefulWidget {
  const HarborIllustration({super.key});

  @override
  State<HarborIllustration> createState() => _HarborIllustrationState();
}

class _HarborIllustrationState extends State<HarborIllustration>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond,
  );
  final _seconds = ValueNotifier<double>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.isMotionReduced) {
      _ticker.stop();
      _seconds.value = _HarborPainter.staticFrameTime;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _HarborPainter.paletteOf(context);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) => RepaintBoundary(
          child: CustomPaint(
            size: Size(
              constraints.maxWidth,
              _HarborPainter.heightFor(constraints.maxWidth),
            ),
            painter: _HarborPainter(seconds: _seconds, palette: palette),
          ),
        ),
      ),
    );
  }
}

typedef _Palette = ({
  Color skyTop,
  Color skyMid,
  Color page,
  Color sun,
  Color lamp,
  double beam,
  Color sea1,
  Color sea2,
  Color sail,
  Color surface,
  Color border,
  Color outline,
  Color muted,
  Color roof,
  bool hasStars,
});

/// Drawn on a 412 wide scene whose sea ends at y 252, scaled to the width.
class _HarborPainter extends CustomPainter {
  _HarborPainter({required this.seconds, required this.palette})
    : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final _Palette palette;

  static const _width = 412.0;
  static const _bottom = 252.0;
  static const _maxScale = 1.25;
  static const staticFrameTime = 3.0;
  static const _accent = AnchorTokens.colorBrandOrange;
  static const _lamp = Offset(335, 158.5);
  static const _stars = [
    (40.0, 70.0, 1.2),
    (92.0, 52.0, 1.0),
    (150.0, 86.0, 1.4),
    (196.0, 48.0, 1.0),
    (238.0, 92.0, 1.1),
    (276.0, 58.0, 1.3),
    (372.0, 74.0, 1.0),
    (24.0, 120.0, 0.9),
    (210.0, 128.0, 1.0),
  ];
  static const _glints = [(212.0, 34.0), (217.0, 22.0), (222.0, 12.0)];

  static double heightFor(double width) =>
      _bottom * math.min(width / _width, _maxScale);

  static _Palette paletteOf(BuildContext context) {
    final colors = context.anchor;
    final base = (
      page: colors.appPage,
      surface: colors.appSurface,
      border: colors.appBorder,
      outline: colors.appText,
      muted: colors.appMuted,
      roof: colors.accentStrong,
    );
    if (context.isDark) {
      return (
        skyTop: const Color(0xFF2B3352),
        skyMid: const Color(0xFF22273A),
        page: base.page,
        sun: const Color(0xFFE9E4D6),
        lamp: const Color(0xFFFFCF8F),
        beam: 0.5,
        sea1: Color.lerp(base.page, const Color(0xFF5C6F95), 0.26)!,
        sea2: Color.lerp(base.page, const Color(0xFF5C6F95), 0.14)!,
        sail: Color.lerp(const Color(0xFFE9E4D6), base.page, 0.12)!,
        surface: base.surface,
        border: base.border,
        outline: base.outline,
        muted: base.muted,
        roof: base.roof,
        hasStars: true,
      );
    }
    return (
      skyTop: Color.lerp(base.page, _accent, 0.24)!,
      skyMid: Color.lerp(base.page, _accent, 0.07)!,
      page: base.page,
      sun: Color.lerp(Colors.white, _accent, 0.62)!,
      lamp: const Color(0xFFFFD8A6),
      beam: 0.32,
      sea1: Color.lerp(base.page, const Color(0xFF6F86A8), 0.22)!,
      sea2: Color.lerp(base.page, const Color(0xFF6F86A8), 0.13)!,
      sail: base.surface,
      surface: base.surface,
      border: base.border,
      outline: base.outline,
      muted: base.muted,
      roof: base.roof,
      hasStars: false,
    );
  }

  /// 0 to 1 and back over [period] seconds, easing at both ends.
  static double _swing(double time, double period) =>
      (1 - math.cos(2 * math.pi * time / period)) / 2;

  static double _drift(double time, double period, double length) =>
      time / period % 1 * length;

  /// A wave along [y] repeating every [length], shifted by [shift], closed
  /// off at [edge] above or below it.
  static Path _wave(
    double y,
    double rise,
    double length,
    double shift, {
    required double left,
    required double right,
    required double edge,
  }) {
    final start = shift - length * (((shift - left) / length).floor() + 1);
    final path = Path()..moveTo(start, y);
    var x = start;
    for (var isUp = true; x < right; x += length / 2, isUp = !isUp) {
      path.quadraticBezierTo(
        x + length / 4,
        isUp ? y - rise : y + rise,
        x + length / 2,
        y,
      );
    }
    return path
      ..lineTo(x, edge)
      ..lineTo(start, edge)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = seconds.value;
    final colors = palette;
    final scale = math.min(size.width / _width, _maxScale);
    final inset = (size.width - _width * scale) / 2 / scale;
    final left = -inset;
    final right = _width + inset;
    final top = _bottom - size.height / scale;

    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(inset * scale, size.height - _bottom * scale)
      ..scale(scale)
      ..clipPath(
        _wave(
          246,
          3,
          140,
          -_drift(time, 13, 140),
          left: left,
          right: right,
          edge: top,
        ),
      );

    canvas.drawRect(
      Rect.fromLTRB(left, top, right, 300),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, 300),
          [colors.skyTop, colors.skyMid, colors.page],
          [0, 0.55, 1],
        ),
    );

    if (colors.hasStars) {
      for (final (i, (x, y, radius)) in _stars.indexed) {
        final n = i + 1;
        final (period, lead) = n % 3 == 0
            ? (11.0, 6.0)
            : n.isEven
            ? (9.0, 3.0)
            : (7.0, 0.0);
        canvas.drawCircle(
          Offset(x, y),
          radius,
          Paint()
            ..color = colors.outline.withValues(
              alpha: 0.55 - 0.4 * _swing(time + lead, period),
            ),
        );
      }
    }

    final glow = _swing(time, 8);
    const sun = Offset(112, 168);
    final halo = 0.3 + 0.15 * glow;
    canvas
      ..drawCircle(
        sun,
        64,
        Paint()
          ..shader = ui.Gradient.radial(
            sun,
            64,
            [
              colors.sun.withValues(alpha: halo),
              colors.sun.withValues(alpha: halo * 0.35),
              colors.sun.withValues(alpha: 0),
            ],
            [0.36, 0.6, 1],
          ),
      )
      ..drawCircle(sun, 24, Paint()..color = colors.sun);

    canvas
      ..save()
      ..translate(_lamp.dx, _lamp.dy)
      ..rotate((-7 + 16 * _swing(time, 18)) * math.pi / 180)
      ..translate(-_lamp.dx, -_lamp.dy)
      ..drawPath(
        Path()
          ..moveTo(_lamp.dx, _lamp.dy)
          ..lineTo(152, 118.5)
          ..quadraticBezierTo(142, 152.5, 152, 198.5)
          ..close(),
        Paint()
          ..shader = ui.Gradient.linear(_lamp, const Offset(145, 158.5), [
            colors.lamp.withValues(alpha: 0.9 * colors.beam),
            colors.lamp.withValues(alpha: 0),
          ]),
      )
      ..restore();

    canvas.drawPath(
      _wave(
        206,
        2.5,
        120,
        -_drift(time, 26, 120),
        left: left,
        right: right,
        edge: 300,
      ),
      Paint()..color = colors.sea1,
    );

    for (final (i, (y, width)) in _glints.indexed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(sun.dx, y), width: width, height: 1.6),
          const Radius.circular(0.8),
        ),
        Paint()
          ..color = colors.sun.withValues(
            alpha: 0.15 + 0.4 * _swing(time + 1.7 * i, 5),
          ),
      );
    }

    _paintBoat(canvas, _swing(time, 6));
    _paintLighthouse(canvas);

    canvas
      ..drawPath(
        _wave(
          226,
          3,
          90,
          _drift(time, 18, 90) - 90,
          left: left,
          right: right,
          edge: 300,
        ),
        Paint()..color = colors.sea2,
      )
      ..restore();
  }

  void _paintBoat(Canvas canvas, double rock) {
    final colors = palette;
    const pivot = Offset(220, 217.8);
    final outlinePaint = Paint()
      ..color = colors.outline.withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final mainsail = Path()
      ..moveTo(223, 175)
      ..quadraticBezierTo(238, 189, 243, 207)
      ..lineTo(223, 207)
      ..close();
    final jib = Path()
      ..moveTo(221, 179)
      ..lineTo(217, 206)
      ..lineTo(200, 207)
      ..close();
    final sailEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..color = colors.border;
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy + 2.5 * rock)
      ..rotate((-3 + 5.5 * rock) * math.pi / 180)
      ..translate(-pivot.dx, -pivot.dy)
      ..drawPath(mainsail, Paint()..color = colors.sail)
      ..drawPath(jib, Paint()..color = colors.sail)
      ..drawPath(mainsail, sailEdge)
      ..drawPath(jib, sailEdge)
      ..drawLine(const Offset(222, 210), const Offset(222, 171), outlinePaint)
      ..drawLine(
        const Offset(222, 208),
        const Offset(244, 208),
        Paint()
          ..color = outlinePaint.color
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        Path()
          ..moveTo(222, 171)
          ..lineTo(230, 173.5)
          ..lineTo(222, 176)
          ..close(),
        Paint()..color = _accent,
      )
      ..drawPath(
        Path()
          ..moveTo(191, 210)
          ..lineTo(247, 210)
          ..lineTo(243.5, 219.6)
          ..quadraticBezierTo(242.6, 222, 240, 222)
          ..lineTo(205, 222)
          ..quadraticBezierTo(196, 219.5, 191, 210)
          ..close(),
        outlinePaint,
      )
      ..restore();
  }

  void _paintLighthouse(Canvas canvas) {
    final colors = palette;
    final tower = Path()
      ..moveTo(324, 210)
      ..lineTo(328, 164)
      ..lineTo(342, 164)
      ..lineTo(346, 210)
      ..close();
    canvas
      ..drawPath(
        Path()
          ..moveTo(284, 232)
          ..quadraticBezierTo(294, 202, 316, 204)
          ..quadraticBezierTo(330, 194, 348, 206)
          ..quadraticBezierTo(368, 212, 376, 232)
          ..close(),
        Paint()..color = Color.lerp(colors.sea1, colors.muted, 0.55)!,
      )
      ..drawPath(tower, Paint()..color = colors.surface)
      ..drawPath(
        tower,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = colors.border,
      )
      ..drawPath(
        Path()
          ..moveTo(326.3, 184)
          ..lineTo(343.7, 184)
          ..lineTo(344.6, 194)
          ..lineTo(325.4, 194)
          ..close()
          ..moveTo(327.6, 170)
          ..lineTo(342.4, 170)
          ..lineTo(343, 176)
          ..lineTo(327, 176)
          ..close(),
        Paint()..color = _accent,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(327, 153, 16, 11),
          const Radius.circular(2),
        ),
        Paint()..color = colors.lamp,
      )
      ..drawPath(
        Path()
          ..moveTo(325, 153)
          ..lineTo(335, 144)
          ..lineTo(345, 153)
          ..close(),
        Paint()..color = colors.roof,
      )
      ..drawLine(
        const Offset(325, 164),
        const Offset(345, 164),
        Paint()
          ..color = colors.outline.withValues(alpha: 0.6)
          ..strokeWidth = 1.6,
      );
  }

  @override
  bool shouldRepaint(_HarborPainter old) =>
      old.seconds != seconds || old.palette != palette;
}
