import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/haptics.dart';
import '../motion/springs.dart';
import '../theme/context_extensions.dart';

/// How long a card takes to rise out of the trash.
const revivalDuration = Duration(milliseconds: 950);

/// How long a card greets you where it went back to.
const welcomeDuration = Duration(milliseconds: 1100);

/// The cards on screen that can be brought back, by note id.
final _cards = <String, RevivableState>{};

/// Something brought back from the trash, as the + of Anchor+ adds: it
/// glows, a light runs across it, and little +s fly out around it. Leaving
/// the trash, it then lifts away and stays invisible, for its owner to
/// remove; arriving where it went back to, it settles in place. Given an
/// [id], it's the card of that note; see [reviveNoteCards] and
/// [welcomeNoteCard].
class Revivable extends StatefulWidget {
  const Revivable({
    super.key,
    this.id,
    required this.borderRadius,
    required this.child,
  });

  final String? id;

  /// The card's corners, which the light keeps within.
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<Revivable> createState() => RevivableState();
}

class RevivableState extends State<Revivable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
  );
  late final _seed = widget.id.hashCode;

  /// Leaving (it lifts away) rather than arriving (it settles).
  bool _isLeaving = false;

  /// Gone from the trash, until its owner removes it.
  bool _isGone = false;

  @override
  void initState() {
    super.initState();
    _register(widget.id);
  }

  @override
  void didUpdateWidget(Revivable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _forget(oldWidget.id);
      _register(widget.id);
    }
  }

  void _register(String? id) {
    if (id != null) _cards[id] = this;
  }

  // A card dragged in hand is a second copy: only forget our own.
  void _forget(String? id) {
    if (id != null && _cards[id] == this) _cards.remove(id);
  }

  @override
  void dispose() {
    _forget(widget.id);
    _controller.dispose();
    super.dispose();
  }

  /// Rises out of the trash; completes when it's gone. Straight away with
  /// animations turned off.
  Future<void> leave() => _play(isLeaving: true);

  /// Greets you where it went back to.
  Future<void> welcome() => _play(isLeaving: false);

  Future<void> _play({required bool isLeaving}) async {
    if (context.isMotionReduced || _controller.isAnimating) return;
    isLeaving ? Haptics.medium() : Haptics.light();
    setState(() {
      _isLeaving = isLeaving;
      _isGone = false;
    });
    _controller.duration = isLeaving ? revivalDuration : welcomeDuration;
    try {
      await _controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() {
      _isGone = isLeaving;
      _controller.value = 0;
    });
  }

  /// Shows it again, as it was; for when bringing it back failed.
  void showAgain() {
    if (!_isGone && !_controller.isAnimating) return;
    _controller
      ..stop()
      ..value = 0;
    setState(() => _isGone = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    // The same tree whether or not it plays, so the card keeps its state.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final isPlaying = _controller.isAnimating;
        final (scale, lift, opacity) = !isPlaying
            ? (1.0, 0.0, _isGone ? 0.0 : 1.0)
            : _isLeaving
            ? _leaving(t)
            : _arriving(t);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, lift),
            child: Transform.scale(
              scale: scale,
              child: CustomPaint(
                painter: isPlaying
                    ? _HaloPainter(
                        glow: _glow(t),
                        color: colors.accentStrong,
                        borderRadius: widget.borderRadius,
                      )
                    : null,
                foregroundPainter: isPlaying
                    ? _RevivalPainter(
                        t: t,
                        seed: _seed,
                        borderRadius: widget.borderRadius,
                        accent: colors.accentStrong,
                        ink: colors.accentInk,
                      )
                    : null,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }

  /// A pop as it lights up, then it lifts away, shrinking and fading.
  static (double, double, double) _leaving(double t) {
    if (t < 0.3) {
      final p = Curves.easeOutBack.transform(t / 0.3);
      return (1 + 0.05 * p, 0, 1);
    }
    final p = Curves.easeInCubic.transform((t - 0.3) / 0.7);
    return (1.05 - 0.45 * p, -48 * p, 1 - p);
  }

  /// In a little small, swells past its size, settles.
  static (double, double, double) _arriving(double t) {
    if (t < 0.35) {
      final p = Curves.easeOutCubic.transform(t / 0.35);
      return (0.94 + 0.1 * p, 0, 1);
    }
    final p = Curves.easeInOutCubic.transform(((t - 0.35) / 0.4).clamp(0, 1));
    return (1.04 - 0.04 * p, 0, 1);
  }

  /// The glow rises quickly and fades slowly.
  static double _glow(double t) =>
      t < 0.25 ? Curves.easeOut.transform(t / 0.25) : 1 - (t - 0.25) / 0.75;
}

/// The glow around the card, under it.
class _HaloPainter extends CustomPainter {
  _HaloPainter({
    required this.glow,
    required this.color,
    required this.borderRadius,
  });

  final double glow;
  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow <= 0) return;
    final rect = (Offset.zero & size).inflate(4 * glow);
    canvas.drawRRect(
      borderRadius.toRRect(rect),
      Paint()
        ..color = color.withValues(alpha: 0.55 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 10 * glow),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.glow != glow || old.color != color;
}

/// The light running across the card and the +s flying out around it.
class _RevivalPainter extends CustomPainter {
  _RevivalPainter({
    required this.t,
    required this.seed,
    required this.borderRadius,
    required this.accent,
    required this.ink,
  });

  final double t;
  final int seed;
  final BorderRadius borderRadius;
  final Color accent;
  final Color ink;

  static const _sparks = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // A light running across, top left to bottom right, as on the +.
    final sweep = ((t - 0.05) / 0.55).clamp(0.0, 1.0) * 1.6 - 0.3;
    if (sweep > -0.3 && sweep < 1.3) {
      canvas.save();
      canvas.clipRRect(borderRadius.toRRect(rect));
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0),
            ],
            stops: [
              (sweep - 0.18).clamp(0.0, 1.0),
              sweep.clamp(0.0, 1.0),
              (sweep + 0.18).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
      );
      canvas.restore();
    }

    // The +s: out from the card's edge, fading on the way.
    final burst = ((t - 0.08) / 0.8).clamp(0.0, 1.0);
    if (burst <= 0 || burst >= 1) return;
    final progress = Curves.easeOutCubic.transform(burst);
    final opacity = (1 - burst) * math.min(1, burst * 6);
    final random = math.Random(seed);
    final center = rect.center;
    for (var i = 0; i < _sparks; i++) {
      final angle =
          -math.pi / 2 + (i + random.nextDouble() * 0.6) * 2 * math.pi / _sparks;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final edge = Offset(
        direction.dx * size.width / 2,
        direction.dy * size.height / 2,
      );
      final reach = 18 + 26 * random.nextDouble();
      final at = center + edge * 0.9 + direction * reach * progress;
      final arm = (3 + 3 * random.nextDouble()) * (0.5 + 0.5 * progress);
      final color = (i.isEven ? accent : ink).withValues(
        alpha: opacity.clamp(0.0, 1.0),
      );
      if (i % 3 == 2) {
        canvas.drawCircle(at, arm * 0.45, Paint()..color = color);
        continue;
      }
      final bar = arm * 0.55;
      final paint = Paint()..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: arm * 2, height: bar),
          Radius.circular(bar / 2),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: bar, height: arm * 2),
          Radius.circular(bar / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RevivalPainter old) =>
      old.t != t || old.accent != accent || old.ink != ink;
}

/// Brings the cards of notes [ids] that are on screen out of the trash;
/// completes when they're gone, for the notes to be restored then.
Future<void> reviveNoteCards(Iterable<String> ids) => Future.wait([
  for (final id in ids)
    if (_cards[id] case final card?) card.leave(),
]);

/// Shows the cards of notes [ids] again, for when restoring failed.
void showRevivedNoteCards(Iterable<String> ids) {
  for (final id in ids) {
    _cards[id]?.showAgain();
  }
}

/// Greets you with note [id]'s card, where it went back to; false when it
/// isn't on screen.
bool welcomeNoteCard(String id) {
  final card = _cards[id];
  if (card == null || !card.mounted) return false;
  unawaited(card.welcome());
  return true;
}
