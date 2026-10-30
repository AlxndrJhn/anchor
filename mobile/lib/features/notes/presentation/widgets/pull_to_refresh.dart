import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_glyph.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/l10n.dart';

class PullToRefresh extends StatefulWidget {
  const PullToRefresh({
    super.key,
    required this.onSync,
    required this.isOnline,
  });

  /// Completes with whether everything synced.
  final Future<bool> Function() onSync;
  final bool Function() isOnline;

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> {
  final ValueNotifier<String?> _announcement = ValueNotifier(null);
  bool _isArmed = false;

  @override
  void dispose() {
    _announcement.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final l10n = context.l10n;
    if (!widget.isOnline()) {
      await _announce(l10n.pullOffline, const Duration(milliseconds: 1600));
      return;
    }
    _announcement.value = l10n.pullSyncing;
    final isSynced = await widget.onSync();
    if (!mounted) return;
    if (isSynced) {
      Haptics.success();
      await _announce(l10n.pullUpToDate, const Duration(milliseconds: 700));
    } else {
      Haptics.warning();
      await _announce(l10n.pullFailed, const Duration(milliseconds: 1600));
    }
  }

  Future<void> _announce(String text, Duration duration) async {
    _announcement.value = text;
    await Future<void>.delayed(duration);
    if (mounted) _announcement.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: 78,
      refreshIndicatorExtent: 70,
      onRefresh: _refresh,
      builder: (context, mode, pulled, trigger, extent) {
        final armed =
            mode == RefreshIndicatorMode.armed ||
            mode == RefreshIndicatorMode.refresh;
        if (armed != _isArmed) {
          _isArmed = armed;
          if (mode == RefreshIndicatorMode.armed) Haptics.light();
        }
        return _PullIndicator(
          pulled: pulled,
          mode: mode,
          announcement: _announcement,
        );
      },
    );
  }
}

class _PullIndicator extends StatefulWidget {
  const _PullIndicator({
    required this.pulled,
    required this.mode,
    required this.announcement,
  });

  final double pulled;
  final RefreshIndicatorMode mode;
  final ValueNotifier<String?> announcement;

  @override
  State<_PullIndicator> createState() => _PullIndicatorState();
}

class _PullIndicatorState extends State<_PullIndicator>
    with TickerProviderStateMixin {
  // Swings the anchor while syncing, and takes its sparks round once a swing.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: AnchorTokens.motionDurationSway,
  );

  // Sparks thrown out once as the pull arms.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(_PullIndicator old) {
    super.didUpdateWidget(old);
    final syncing = widget.mode == RefreshIndicatorMode.refresh;
    if (syncing && !_sway.isAnimating && !context.isMotionReduced) {
      _sway.repeat();
    } else if (!syncing && _sway.isAnimating) {
      _sway.stop();
      _sway.value = 0;
    }
    if (widget.mode == RefreshIndicatorMode.armed &&
        old.mode != RefreshIndicatorMode.armed &&
        !context.isMotionReduced) {
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final pulled = widget.pulled;
    final mode = widget.mode;
    final armed =
        mode == RefreshIndicatorMode.armed ||
        mode == RefreshIndicatorMode.refresh;
    final syncing = mode == RefreshIndicatorMode.refresh;
    final tilt = syncing ? 0.0 : (pulled - 60) * 0.12 * math.pi / 180;
    return OverflowBox(
      alignment: Alignment.topCenter,
      maxHeight: 200, // off-scale: room for the rope while pulling
      child: Transform.translate(
        offset: Offset(
          0,
          RefreshInset.of(context) - 6, // off-scale: just under the bar's edge
        ),
        // A message draws the anchor up to the bar.
        child: ValueListenableBuilder<String?>(
          valueListenable: widget.announcement,
          builder: (context, announcement, anchor) =>
              TweenAnimationBuilder<double>(
                tween: Tween(end: announcement == null ? 1 : 0),
                duration: context.motion(AnchorTokens.motionDurationFade),
                builder: (context, ropeShown, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 1.5,
                      height:
                          math.max(0, math.min(pulled, 120) - 34) *
                          ropeShown, // off-scale: the rope
                      color: colors.appMuted.withValues(alpha: 0.55),
                    ),
                    anchor!,
                    AnimatedOpacity(
                      opacity: announcement == null ? 0 : 1,
                      duration: context.motion(AnchorTokens.motionDurationFade),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text(
                          announcement ?? '',
                          textAlign: TextAlign.center,
                          style: AppTypography.secondary.copyWith(
                            color: colors.appMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          child: Opacity(
            opacity: (pulled / 40).clamp(0.0, 1.0),
            child: AnimatedBuilder(
              animation: Listenable.merge([_sway, _burst]),
              builder: (context, _) {
                final sway = syncing
                    ? math.sin(_sway.value * 2 * math.pi) * 9 * math.pi / 180
                    : tilt;
                // As the + of Anchor+ (see AnchorPlusMark): a glow, sparks
                // circling and a glint running across, all of which the
                // pull winds up and the sync keeps going.
                final reduced = context.isMotionReduced;
                final charge = syncing
                    ? 1.0
                    : ((pulled - 24) / (78 - 24)).clamp(0.0, 1.0);
                final phase = reduced ? 0.0 : pulled / 78 * 0.5 + _sway.value;
                final glint = syncing
                    ? _sway.value * 3 - 1
                    : charge * 1.5 - 0.25;
                final glyphColor = armed
                    ? colors.appOnInverse
                    : colors.appMuted;
                return Transform.rotate(
                  angle: sway,
                  alignment: Alignment.topCenter,
                  child: CustomPaint(
                    painter: _AuraPainter(
                      isFront: false,
                      phase: phase,
                      charge: charge,
                      burst: _burst.value,
                      glint: glint,
                      accent: colors.accentStrong,
                      ink: colors.accentInk,
                    ),
                    foregroundPainter: _AuraPainter(
                      isFront: true,
                      phase: phase,
                      charge: charge,
                      burst: _burst.value,
                      glint: glint,
                      accent: colors.accentStrong,
                      ink: colors.accentInk,
                    ),
                    child: AnimatedContainer(
                      duration: context.motion(AnchorTokens.motionDurationFade),
                      width: AnchorTokens.sizeControlSmall,
                      height: AnchorTokens.sizeControlSmall,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: armed
                            ? colors.appInverse
                            : colors.appInverse.withValues(alpha: 0),
                      ),
                      child: Center(
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              glyphColor,
                              glyphColor,
                              reduced ? glyphColor : colors.accentStrong,
                              glyphColor,
                              glyphColor,
                            ],
                            stops: [
                              0,
                              (glint - 0.3).clamp(0.0, 1.0),
                              glint.clamp(0.0, 1.0),
                              (glint + 0.3).clamp(0.0, 1.0),
                              1,
                            ],
                          ).createShader(bounds),
                          child: AnchorGlyph(
                            size: AnchorTokens.sizeIconMedium,
                            color: glyphColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The glow under the anchor and the three sparks circling it on a tilted
/// ring, as around the + of Anchor+; the back paints the glow and the sparks
/// behind, the front ([isFront]) the sparks before it and the ones thrown out
/// as the pull arms.
class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.isFront,
    required this.phase,
    required this.charge,
    required this.burst,
    required this.glint,
    required this.accent,
    required this.ink,
  });

  final bool isFront;
  final double phase;

  /// How far the pull has wound it up, 0 to 1.
  final double charge;
  final double burst;
  final double glint;
  final Color accent;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final wave = (math.sin(phase * 2 * math.pi) + 1) / 2;

    if (!isFront && charge > 0) {
      final radius = side * 1.1;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: (0.22 + 0.14 * wave) * charge),
              accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    if (charge > 0) {
      for (var i = 0; i < 3; i++) {
        final a = (phase + i / 3) * 2 * math.pi;
        final depth = math.sin(a);
        if ((depth >= 0) != isFront) continue;
        final ring = Offset(math.cos(a) * side * 0.85, depth * side * 0.28);
        final tilt = Offset(
          ring.dx * math.cos(-0.5) - ring.dy * math.sin(-0.5),
          ring.dx * math.sin(-0.5) + ring.dy * math.cos(-0.5),
        );
        final near = (depth + 1) / 2;
        canvas.drawCircle(
          center + tilt,
          side * (0.04 + 0.04 * near) * (0.5 + 0.5 * charge),
          Paint()..color = ink.withValues(alpha: (0.35 + 0.65 * near) * charge),
        );
      }
    }

    // The + of Anchor+ at the anchor's top right, as in the logo: it bobs
    // with the sparks, pops as the pull arms, and the glint runs across it.
    if (isFront) {
      final pop = 1 + 0.45 * math.sin(burst * math.pi);
      final arm = side * 0.15 * pop;
      final bar = arm * 0.5;
      final at =
          center +
          Offset(side * 0.3, -side * 0.3 + math.sin(phase * 2 * math.pi) * 1.2);
      final cross = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: at, width: arm * 2, height: bar),
            Radius.circular(bar / 2),
          ),
        )
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: at, width: bar, height: arm * 2),
            Radius.circular(bar / 2),
          ),
        );
      canvas.drawPath(
        cross,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ink, accent, CupertinoColors.white, accent, ink],
            stops: [
              0,
              (glint - 0.25).clamp(0.0, 1.0),
              glint.clamp(0.0, 1.0),
              (glint + 0.25).clamp(0.0, 1.0),
              1,
            ],
          ).createShader(Rect.fromCircle(center: at, radius: arm)),
      );
    }

    if (isFront && burst > 0 && burst < 1) {
      final progress = Curves.easeOutCubic.transform(burst);
      final paint = Paint()..color = ink.withValues(alpha: 1 - burst);
      for (var i = 0; i < 8; i++) {
        final angle = -math.pi / 2 + i * 2 * math.pi / 8;
        final reach = side * (0.6 + 0.9 * progress);
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * reach,
          side * 0.06 * (1 - burst * 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.isFront != isFront ||
      old.phase != phase ||
      old.charge != charge ||
      old.burst != burst ||
      old.glint != glint ||
      old.accent != accent ||
      old.ink != ink;
}
