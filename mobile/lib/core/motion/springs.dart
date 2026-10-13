import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens/anchor_tokens.dart';

enum Spring {
  smooth(
    AnchorTokens.motionSpringSmoothDuration,
    AnchorTokens.motionSpringSmoothBounce,
  ),

  snappy(
    AnchorTokens.motionSpringSnappyDuration,
    AnchorTokens.motionSpringSnappyBounce,
  ),

  pop(AnchorTokens.motionSpringPopDuration, AnchorTokens.motionSpringPopBounce),

  keyboard(
    AnchorTokens.motionSpringKeyboardDuration,
    AnchorTokens.motionSpringKeyboardBounce,
  );

  const Spring(this.duration, this._bounce);

  final Duration duration;
  final double _bounce;

  Curve get curve => _curves[index];

  /// Starts at [velocity] (units per second) and lands exactly on [to] once
  /// it is within [precision] of it.
  Simulation simulation(
    double from,
    double to, {
    double velocity = 0,
    double precision = 0.0005,
  }) => _SettlingSpring(
    SpringSimulation(
      _descriptions[index],
      from,
      to,
      velocity,
      tolerance: Tolerance(distance: precision, velocity: precision * 20),
    ),
    to,
  );

  static final List<SpringDescription> _descriptions = [
    for (final spring in values)
      SpringDescription.withDurationAndBounce(
        duration: spring.duration,
        bounce: spring._bounce,
      ),
  ];

  static final List<Curve> _curves = [
    for (final spring in values) _SpringCurve(spring.simulation(0, 1)),
  ];
}

class _SettlingSpring extends Simulation {
  _SettlingSpring(this._spring, this._to) : super(tolerance: _spring.tolerance);

  final SpringSimulation _spring;
  final double _to;

  @override
  double x(double time) => _spring.isDone(time) ? _to : _spring.x(time);

  @override
  double dx(double time) => _spring.isDone(time) ? 0 : _spring.dx(time);

  @override
  bool isDone(double time) => _spring.isDone(time);
}

class _SpringCurve extends Curve {
  _SpringCurve(this._run);

  final Simulation _run;

  late final double _end = _settleTime();

  double _settleTime() {
    var time = 0.0;
    while (time < 3 && !_run.isDone(time)) {
      time += 1 / 240;
    }
    return time;
  }

  @override
  double transformInternal(double t) => t >= 1 ? 1 : _run.x(t * _end);
}

/// Android's Remove animations comes through [disableAnimations]; iOS's
/// Reduce Motion has its own flag.
bool _reducesMotion(bool disableAnimations) =>
    disableAnimations ||
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;

/// The system's reduced motion setting, for code without a [BuildContext].
bool get isSystemMotionReduced =>
    _reducesMotion(SemanticsBinding.instance.disableAnimations);

extension SpringController on AnimationController {
  /// [velocity] is in units per second; with reduced motion it jumps
  /// straight there.
  TickerFuture springTo(
    double target, {
    Spring spring = Spring.smooth,
    double velocity = 0,
  }) {
    if (isSystemMotionReduced) {
      value = target;
      return TickerFuture.complete();
    }
    return animateWith(spring.simulation(value, target, velocity: velocity));
  }

  /// [springTo] in reverse: the controller ends dismissed.
  TickerFuture springBackTo(
    double target, {
    Spring spring = Spring.smooth,
    double velocity = 0,
  }) {
    if (isSystemMotionReduced) {
      value = target;
      return TickerFuture.complete();
    }
    return animateBackWith(
      spring.simulation(value, target, velocity: velocity),
    );
  }
}

extension ReducedMotion on BuildContext {
  bool get isMotionReduced =>
      _reducesMotion(MediaQuery.maybeDisableAnimationsOf(this) ?? false);

  /// [duration], or no time at all with reduced motion.
  Duration motion(Duration duration) =>
      isMotionReduced ? Duration.zero : duration;
}
