import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How long cards fly into their new places, gathering speed.
const strikeTravel = Duration(milliseconds: 230);

/// How long the knock back from the impact takes.
const strikeBounce = Duration(milliseconds: 140);

/// How long the sparks of the impact fly.
const strikeSparks = Duration(milliseconds: 420);

/// After a delete, how long cards that move strike into their places
/// instead of jumping there.
const _armedFor = Duration(milliseconds: 2500);

DateTime? _armedUntil;
DateTime? _lastKnock;

/// Makes the cards that move in the next moments, as deleted notes leave
/// their lists, fly into their new places and strike them; see [Strike].
void armCardStrike() => _armedUntil = DateTime.now().add(_armedFor);

@visibleForTesting
void disarmCardStrike() => _armedUntil = null;

bool get _isArmed {
  final until = _armedUntil;
  return until != null && DateTime.now().isBefore(until);
}

/// Where a card that moved by [from] (its old place less its new one) is
/// drawn at [t] of the strike: it speeds up all the way to its place, knocks
/// back a little on the impact, and settles.
@visibleForTesting
Offset strikeOffset(Offset from, Duration t) {
  final travel = t.inMicroseconds / strikeTravel.inMicroseconds;
  if (travel < 1) return from * (1 - Curves.easeInCubic.transform(travel));
  final bounce =
      (t - strikeTravel).inMicroseconds / strikeBounce.inMicroseconds;
  if (bounce >= 1 || from.distance == 0) return Offset.zero;
  final knock = math.min(6.0, from.distance * 0.06);
  return from /
      from.distance *
      knock *
      math.sin(math.pi * Curves.easeOut.transform(bounce));
}

/// Moves its card to a new place, after a delete ([armCardStrike]), as if
/// it were struck there with a hammer: it speeds up, hits, knocks back a
/// little and throws a few sparks, like steel hit on an anvil. Other moves
/// (scrolling, dragging, sorting) are left alone.
///
/// It sees it moved when it's drawn again, so it mustn't sit in a
/// [RepaintBoundary] of its own: lists of them leave out theirs
/// (`addRepaintBoundaries: false`).
class Strike extends StatefulWidget {
  const Strike({super.key, required this.child});

  final Widget child;

  @override
  State<Strike> createState() => _StrikeState();
}

class _StrikeState extends State<Strike> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  ScrollableState? _scrollable;
  bool _reduceMotion = false;

  AnimationController get controller => _controller ??= AnimationController(
    vsync: this,
    duration: strikeTravel + strikeSparks,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // The outermost list: a card also moves when a section above it, a
    // list of its own, gets shorter.
    var scrollable = context.findAncestorStateOfType<ScrollableState>();
    while (scrollable != null) {
      final outer = scrollable.context
          .findAncestorStateOfType<ScrollableState>();
      if (outer == null) break;
      scrollable = outer;
    }
    _scrollable = scrollable;
  }

  /// Where the card is in its list, wherever that's scrolled to.
  Offset? _placeOf(RenderBox box) {
    final scrollable = _scrollable;
    if (scrollable == null || !scrollable.mounted) return null;
    final list = scrollable.context.findRenderObject();
    if (list is! RenderBox ||
        !list.attached ||
        !scrollable.position.hasPixels) {
      return null;
    }
    final scrolled = scrollable.position.pixels;
    final inView = box.localToGlobal(Offset.zero, ancestor: list);
    return switch (scrollable.axisDirection) {
      AxisDirection.down => inView + Offset(0, scrolled),
      AxisDirection.up => inView - Offset(0, scrolled),
      AxisDirection.right => inView + Offset(scrolled, 0),
      AxisDirection.left => inView - Offset(scrolled, 0),
    };
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StrikeBox(state: this, child: widget.child);
}

class _StrikeBox extends SingleChildRenderObjectWidget {
  const _StrikeBox({required this.state, super.child});

  final _StrikeState state;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStrike(state);

  @override
  void updateRenderObject(BuildContext context, _RenderStrike renderObject) =>
      renderObject.state = state;
}

class _Spark {
  _Spark(this.start, this.velocity, this.life, this.length);

  /// Where it flies from, off the middle of the face that hit.
  final Offset start;
  final Offset velocity;
  final double life;
  final double length;
}

class _RenderStrike extends RenderProxyBox {
  _RenderStrike(this.state);

  _StrikeState state;

  static const _gravity = Offset(0, 1400);
  static const _colors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF6C8),
    Color(0xFFFFC94A),
    Color(0xFFFF7A2E),
  ];

  /// Where it was last drawn in its list.
  Offset? _place;

  /// Its old place less its new one, while it strikes.
  Offset? _from;
  bool _starting = false;
  bool _knocked = false;
  Offset _contact = Offset.zero;
  List<_Spark> _sparks = const [];

  AnimationController? _listening;

  Duration get _elapsed {
    final controller = state._controller;
    if (_starting || controller == null) return Duration.zero;
    return controller.duration! * controller.value;
  }

  Offset get _offset {
    final from = _from;
    return from == null ? Offset.zero : strikeOffset(from, _elapsed);
  }

  @override
  void detach() {
    _stop();
    super.detach();
  }

  void _stop() {
    _listening?.removeListener(_tick);
    _listening = null;
    _from = null;
    _starting = false;
  }

  void _tick() {
    final controller = _listening;
    if (controller == null) return;
    if (!_knocked && _elapsed >= strikeTravel) {
      _knocked = true;
      final now = DateTime.now();
      // One knock for all the cards that land together.
      if (_lastKnock == null ||
          now.difference(_lastKnock!) > const Duration(milliseconds: 150)) {
        _lastKnock = now;
        HapticFeedback.lightImpact();
      }
    }
    // Told the last value before it's marked completed.
    if (controller.value >= 1) _stop();
    markNeedsPaint();
  }

  /// Starts striking from [from], its old place less its new one.
  void _strike(Offset from) {
    final random = math.Random();
    final size = this.size;
    final distance = from.distance;
    // It flies against [from]; it hits with its leading edge.
    final heading = -from / distance;
    final reach = math.min(
      heading.dx.abs() < 1e-6
          ? double.infinity
          : size.width / 2 / heading.dx.abs(),
      heading.dy.abs() < 1e-6
          ? double.infinity
          : size.height / 2 / heading.dy.abs(),
    );
    _contact = size.center(Offset.zero) + heading * reach;
    // Along the face it hits, and out to both sides of it, a little ahead.
    final face = Offset(-heading.dy, heading.dx);
    final span = face.dx.abs() * size.width + face.dy.abs() * size.height;
    _sparks = [
      for (var i = 0, n = 4 + random.nextInt(4); i < n; i++)
        () {
          final side = random.nextBool() ? 1.0 : -1.0;
          final tilt = -0.3 + random.nextDouble() * 1.1;
          return _Spark(
            face * (span * (random.nextDouble() - 0.5) * 0.8),
            (face * side * math.cos(tilt) + heading * math.sin(tilt)) *
                (160 + random.nextDouble() * 260),
            0.18 + random.nextDouble() * 0.24,
            4 + random.nextDouble() * 6,
          );
        }(),
    ];
    _from = from;
    _knocked = false;
    _starting = true;
    // The animation can't start while drawing: this frame shows it where it
    // was, and it starts after.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached || !identical(_from, from)) return;
      final controller = state.controller;
      _listening?.removeListener(_tick);
      _listening = controller..addListener(_tick);
      _starting = false;
      controller.forward(from: 0);
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final place = state._placeOf(this);
    final last = _place;
    _place = place;
    if (place != null &&
        last != null &&
        (last - place).distance > 0.5 &&
        _isArmed &&
        !state._reduceMotion) {
      // From where it's seen now, should it be striking already.
      final from = last + _offset - place;
      if (from.distance > 0.5) _strike(from);
    }
    if (_from == null) return super.paint(context, offset);
    super.paint(context, offset + _offset);
    _paintSparks(context.canvas, offset);
  }

  void _paintSparks(Canvas canvas, Offset offset) {
    final since = (_elapsed - strikeTravel).inMicroseconds / 1e6;
    if (since < 0) return;
    final glow = Paint()
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final core = Paint()..strokeCap = StrokeCap.round;
    final origin = offset + _contact;
    for (final spark in _sparks) {
      final age = since / spark.life;
      if (age >= 1) continue;
      final head =
          origin +
          spark.start +
          spark.velocity * since +
          _gravity * (since * since / 2);
      final heading = spark.velocity + _gravity * since;
      final tail =
          head - heading / heading.distance * spark.length * (1 - age * 0.6);
      final band = (age * _colors.length).floor().clamp(0, _colors.length - 1);
      final fade = 1 - Curves.easeIn.transform(age);
      glow
        ..color = const Color(0xFFFF7A2E).withValues(alpha: 0.6 * fade)
        ..strokeWidth = 4;
      core
        ..color = _colors[band].withValues(alpha: fade)
        ..strokeWidth = 1.8 * (1 - age * 0.4);
      canvas
        ..drawLine(tail, head, glow)
        ..drawLine(tail, head, core);
    }
  }
}
