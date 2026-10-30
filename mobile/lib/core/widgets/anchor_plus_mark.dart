import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/haptics.dart';
import '../motion/springs.dart';
import '../theme/context_extensions.dart';

/// The "+" of Anchor+, set after a title: it hovers, glows, and has a few
/// sparks circling it, for everything the + adds. A tap sends the features
/// out around it, as they do once when it first shows. Sits still with
/// reduced motion.
class AnchorPlusMark extends StatefulWidget {
  const AnchorPlusMark({super.key, required this.size});

  /// The height of the cross, about the cap height of the title next to it.
  final double size;

  /// Beside a large title.
  static const titleSize = 24.0;

  /// What a tap sends out: a few of the things Anchor+ adds.
  static const features = <IconData>[
    LucideIcons.lock,
    LucideIcons.snowflake,
    LucideIcons.eyeOff,
    LucideIcons.scanText,
    LucideIcons.palette,
    LucideIcons.gripVertical,
    LucideIcons.flame,
    LucideIcons.images,
  ];

  @override
  State<AnchorPlusMark> createState() => _AnchorPlusMarkState();
}

class _AnchorPlusMarkState extends State<AnchorPlusMark>
    with TickerProviderStateMixin {
  // One hover cycle; the sparks go round once in two.
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  Timer? _firstBurst;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isSystemMotionReduced || MediaQuery.disableAnimationsOf(context)) {
      _hover.stop();
      _firstBurst?.cancel();
    } else if (!_hover.isAnimating) {
      _hover.repeat();
      // Shows once what the + stands for, after the page has settled.
      _firstBurst ??= Timer(
        const Duration(milliseconds: 900),
        () => _burst.forward(from: 0),
      );
    }
  }

  @override
  void dispose() {
    _firstBurst?.cancel();
    _hover.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _celebrate() {
    if (isSystemMotionReduced || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    Haptics.light();
    _burst.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final size = widget.size;
    // The sparks and the burst reach past the cross, so they paint outside
    // the box the title leaves for it.
    return GestureDetector(
      onTap: _celebrate,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_hover, _burst]),
          builder: (context, _) {
            final t = _hover.value;
            final lift = math.sin(t * 2 * math.pi) * size * 0.09;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PlusPainter(
                      phase: t,
                      lift: lift,
                      accent: colors.accentStrong,
                      ink: colors.accentInk,
                    ),
                  ),
                ),
                if (_burst.isAnimating)
                  for (var i = 0; i < AnchorPlusMark.features.length; i++)
                    _feature(i, size, colors.accentInk),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One feature flying out from the cross and fading on the way.
  Widget _feature(int index, double size, Color color) {
    final count = AnchorPlusMark.features.length;
    final progress = Curves.easeOutCubic.transform(_burst.value);
    final angle = -math.pi / 2 + index * 2 * math.pi / count;
    final reach = size * 2.2 * progress;
    final iconSize = size * 0.7;
    final opacity = (1 - _burst.value) * math.min(1, _burst.value * 6);
    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: Offset(math.cos(angle), math.sin(angle)) * reach,
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(
              scale: 0.4 + 0.6 * progress,
              child: Icon(
                AnchorPlusMark.features[index],
                size: iconSize,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  _PlusPainter({
    required this.phase,
    required this.lift,
    required this.accent,
    required this.ink,
  });

  final double phase;
  final double lift;
  final Color accent;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2 + lift);
    final wave = (math.sin(phase * 2 * math.pi) + 1) / 2;

    // The glow under the cross breathes as it rises.
    canvas.drawCircle(
      center,
      side * 0.95,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.28 + 0.14 * wave),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: side * 0.95)),
    );

    // Three sparks on a tilted ring: the ones behind are drawn first,
    // smaller and fainter.
    final sparks = <(double, Offset)>[];
    for (var i = 0; i < 3; i++) {
      final a = (phase / 2 + i / 3) * 2 * math.pi;
      final depth = math.sin(a);
      final ring = Offset(math.cos(a) * side * 0.95, depth * side * 0.32);
      final tilt = Offset(
        ring.dx * math.cos(-0.5) - ring.dy * math.sin(-0.5),
        ring.dx * math.sin(-0.5) + ring.dy * math.cos(-0.5),
      );
      sparks.add((depth, center + tilt));
    }
    sparks.sort((a, b) => a.$1.compareTo(b.$1));
    void spark((double, Offset) s) {
      final near = (s.$1 + 1) / 2;
      canvas.drawCircle(
        s.$2,
        side * (0.05 + 0.05 * near),
        Paint()..color = ink.withValues(alpha: 0.35 + 0.65 * near),
      );
    }

    for (final s in sparks.where((s) => s.$1 < 0)) {
      spark(s);
    }

    // The cross: rounded bars with a light running across them.
    final bar = side * 0.24;
    final arm = side * 0.5;
    final cross = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: arm * 2, height: bar),
          Radius.circular(bar / 2),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: bar, height: arm * 2),
          Radius.circular(bar / 2),
        ),
      );
    final bounds = Rect.fromCircle(center: center, radius: arm);
    final sweep = phase * 3 - 1;
    canvas.drawPath(
      cross,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ink, accent, Colors.white, accent, ink],
          stops: [
            0,
            (sweep - 0.25).clamp(0.0, 1.0),
            sweep.clamp(0.0, 1.0),
            (sweep + 0.25).clamp(0.0, 1.0),
            1,
          ],
        ).createShader(bounds),
    );

    for (final s in sparks.where((s) => s.$1 >= 0)) {
      spark(s);
    }
  }

  @override
  bool shouldRepaint(_PlusPainter old) =>
      old.phase != phase ||
      old.lift != lift ||
      old.accent != accent ||
      old.ink != ink;
}
