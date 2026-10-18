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
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: AnchorTokens.motionDurationSway,
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
  }

  @override
  void dispose() {
    _sway.dispose();
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
              animation: _sway,
              builder: (context, child) {
                final sway = syncing
                    ? math.sin(_sway.value * 2 * math.pi) * 9 * math.pi / 180
                    : tilt;
                return Transform.rotate(
                  angle: sway,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
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
                  child: AnchorGlyph(
                    size: AnchorTokens.sizeIconMedium,
                    color: armed ? colors.appOnInverse : colors.appMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
