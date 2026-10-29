import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'springs.dart';

class AnchorPageTransitionsBuilder extends PageTransitionsBuilder {
  const AnchorPageTransitionsBuilder();

  @override
  Duration get transitionDuration =>
      isSystemMotionReduced ? Duration.zero : Spring.smooth.duration;

  @override
  Duration get reverseTransitionDuration =>
      isSystemMotionReduced ? Duration.zero : const Duration(milliseconds: 420);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Theme.of(context).platform == TargetPlatform.android) {
      return _AndroidPageTransition(
        route: route,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    }
    return const CupertinoPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

enum _BackPhase { idle, gesture, commit }

class _AndroidPageTransition extends StatefulWidget {
  const _AndroidPageTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_AndroidPageTransition> createState() => _AndroidPageTransitionState();
}

class _AndroidPageTransitionState extends State<_AndroidPageTransition>
    with WidgetsBindingObserver {
  _BackPhase _phase = _BackPhase.idle;

  double _side = 1;
  double _progress = 0;
  double _dy = 0;
  double _startY = 0;
  double _commitFrom = 1;
  ({double value, double shown})? _closing;

  bool get _enabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_enabled) return false;
    _side = backEvent.swipeEdge == SwipeEdge.right ? -1 : 1;
    _startY = backEvent.touchOffset?.dy ?? 0;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    setState(() {
      _phase = _BackPhase.gesture;
      _progress = backEvent.progress;
      _dy = 0;
    });
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_phase != _BackPhase.gesture) return;
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
    setState(() {
      _progress = backEvent.progress;
      _dy = (backEvent.touchOffset?.dy ?? _startY) - _startY;
    });
  }

  @override
  void handleCancelBackGesture() {
    if (_phase != _BackPhase.gesture) return;
    widget.route.handleCancelBackGesture();
    setState(() => _phase = _BackPhase.idle);
  }

  @override
  void handleCommitBackGesture() {
    if (_phase != _BackPhase.gesture) return;
    _commitFrom = math.max(0.01, widget.animation.value);
    setState(() => _phase = _BackPhase.commit);
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.animation,
        widget.secondaryAnimation,
      ]),
      child: widget.child,
      builder: (context, child) {
        final dim = _dimOf(widget.secondaryAnimation.value);
        Widget page;
        if (_phase == _BackPhase.gesture && widget.route.popGestureInProgress) {
          page = _shrunk(child!, size, _eased(_progress), 0, 1);
        } else if (_phase == _BackPhase.commit &&
            !widget.animation.isCompleted) {
          final left =
              1 - (widget.animation.value / _commitFrom).clamp(0.0, 1.0);
          page = _shrunk(
            child!,
            size,
            _eased(_progress),
            left * size.width * 0.9,
            (1 - left * 1.6).clamp(0.0, 1.0),
          );
        } else {
          if (_phase != _BackPhase.idle && widget.animation.isCompleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _phase = _BackPhase.idle);
            });
          }
          final progress = _slideIn();
          page = FractionalTranslation(
            translation: Offset(1 - progress, 0),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                boxShadow: progress < 1
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.14 * math.min(1, progress * 1.4),
                          ),
                          blurRadius: 40,
                          offset: const Offset(-16, 0),
                        ),
                      ]
                    : const [],
              ),
              child: child,
            ),
          );
        }
        if (dim <= 0) return page;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            page,
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: dim)),
            ),
          ],
        );
      },
    );
  }

  double _slideIn() {
    final animation = widget.animation;
    final curve = Spring.smooth.curve;
    if (animation.status != AnimationStatus.reverse) {
      _closing = null;
      return curve.transform(animation.value);
    }
    final closing = _closing ??= (
      value: animation.value,
      shown: curve.transform(animation.value),
    );
    if (closing.value == 0) return 0;
    final elapsed = (closing.value - animation.value) / closing.value;
    return closing.shown * (1 - curve.transform(elapsed.clamp(0.0, 1.0)));
  }

  double _eased(double progress) =>
      Curves.easeOut.transform(progress.clamp(0.0, 1.0));

  double _dimOf(double secondary) => 0.1 * secondary;

  Widget _shrunk(
    Widget child,
    Size size,
    double shrink,
    double slide,
    double opacity,
  ) {
    final radius = 34.0 * shrink;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(_side * (8 * shrink + slide), _dy * 0.08),
        child: Transform.scale(
          scale: 1 - 0.1 * shrink,
          alignment: _side < 0 ? Alignment.centerRight : Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: child,
          ),
        ),
      ),
    );
  }
}
