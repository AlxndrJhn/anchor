import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/motion/springs.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';

/// A 3×3 grid of dots to drag across. The dots joined, in order, come out
/// as digits 0-8 (left to right, top to bottom): "03678" is down the left
/// and along the bottom. Passing straight over a dot not yet joined joins
/// it too, as Android's own pattern does.
class LockPatternPad extends StatefulWidget {
  const LockPatternPad({
    super.key,
    required this.onComplete,
    this.isError = false,
    this.enabled = true,
  });

  /// The pattern drawn, once the finger lifts.
  final ValueChanged<String> onComplete;

  /// Draws the last pattern in the error colour, until the next one starts.
  final bool isError;
  final bool enabled;

  static const double maxSide = 288; // off-scale: the pattern grid

  @override
  State<LockPatternPad> createState() => _LockPatternPadState();
}

class _LockPatternPadState extends State<LockPatternPad> {
  final List<int> _dots = [];
  Offset? _finger;
  double _side = 0;

  /// Whether the drawn pattern is the finished one (shown until the next).
  bool _done = false;

  Offset _centre(int dot) {
    final cell = _side / 3;
    return Offset((dot % 3 + 0.5) * cell, (dot ~/ 3 + 0.5) * cell);
  }

  int? _dotAt(Offset position) {
    final cell = _side / 3;
    final hit = cell * 0.32;
    for (var dot = 0; dot < 9; dot++) {
      if ((position - _centre(dot)).distance <= hit) return dot;
    }
    return null;
  }

  void _join(int dot) {
    if (_dots.contains(dot)) return;
    if (_dots.isNotEmpty) {
      final last = _dots.last;
      // A dot straight between the two (a row, column or diagonal).
      final (r1, c1, r2, c2) = (last ~/ 3, last % 3, dot ~/ 3, dot % 3);
      if ((r1 + r2).isEven && (c1 + c2).isEven) {
        final middle = (r1 + r2) ~/ 2 * 3 + (c1 + c2) ~/ 2;
        if (middle != last && middle != dot && !_dots.contains(middle)) {
          _dots.add(middle);
        }
      }
    }
    _dots.add(dot);
    Haptics.selection();
  }

  void _start(Offset position) {
    setState(() {
      _dots.clear();
      _done = false;
      _finger = position;
      final dot = _dotAt(position);
      if (dot != null) _join(dot);
    });
  }

  void _move(Offset position) {
    setState(() {
      _finger = position;
      final dot = _dotAt(position);
      if (dot != null) _join(dot);
    });
  }

  void _end() {
    setState(() {
      _finger = null;
      _done = true;
    });
    if (_dots.isEmpty) return;
    widget.onComplete(_dots.join());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          LockPatternPad.maxSide,
          math.min(
            constraints.maxWidth,
            constraints.hasBoundedHeight ? constraints.maxHeight : 1e9,
          ),
        );
        _side = side;
        return Semantics(
          label: context.l10n.lockPatternGrid,
          child: GestureDetector(
            key: const ValueKey('lock-pattern-pad'),
            behavior: HitTestBehavior.opaque,
            // The first dot is where the finger lands.
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: widget.enabled ? (d) => _start(d.localPosition) : null,
            onPanUpdate: widget.enabled ? (d) => _move(d.localPosition) : null,
            onPanEnd: widget.enabled ? (_) => _end() : null,
            onPanCancel: widget.enabled ? _end : null,
            child: CustomPaint(
              size: Size.square(side),
              painter: _PatternPainter(
                dots: List.of(_dots),
                finger: _finger,
                centre: _centre,
                dotColor: colors.appMuted,
                lineColor: widget.isError && _done
                    ? colors.statusDanger
                    : colors.accentStrong,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.dots,
    required this.finger,
    required this.centre,
    required this.dotColor,
    required this.lineColor,
  });

  final List<int> dots;
  final Offset? finger;
  final Offset Function(int) centre;
  final Color dotColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final line = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..strokeWidth = cell * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (dots.isNotEmpty) {
      final path = Path()..moveTo(centre(dots.first).dx, centre(dots.first).dy);
      for (final dot in dots.skip(1)) {
        path.lineTo(centre(dot).dx, centre(dot).dy);
      }
      if (finger != null) path.lineTo(finger!.dx, finger!.dy);
      canvas.drawPath(path, line);
    }
    for (var dot = 0; dot < 9; dot++) {
      final joined = dots.contains(dot);
      if (joined) {
        canvas.drawCircle(
          centre(dot),
          cell * 0.2,
          Paint()..color = lineColor.withValues(alpha: 0.16),
        );
      }
      canvas.drawCircle(
        centre(dot),
        cell * (joined ? 0.09 : 0.06),
        Paint()..color = joined ? lineColor : dotColor,
      );
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.finger != finger ||
      old.lineColor != lineColor ||
      old.dotColor != dotColor ||
      old.dots.join() != dots.join();
}

/// A numeric keypad with dots for the digits typed so far. OK hands the
/// PIN on; [clearSignal] changing empties it (after a wrong PIN).
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.clearSignal = 0,
    this.maxLength = 12,
  });

  final ValueChanged<String> onSubmit;
  final bool enabled;
  final int clearSignal;
  final int maxLength;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.clearSignal != widget.clearSignal) _pin = '';
  }

  void _type(String digit) {
    if (_pin.length >= widget.maxLength) return;
    Haptics.selection();
    setState(() => _pin += digit);
  }

  void _erase() {
    if (_pin.isEmpty) return;
    Haptics.selection();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_pin.isEmpty) return;
    widget.onSubmit(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final digitStyle = AppTypography.sheetTitle.copyWith(
      color: colors.appText,
      fontWeight: FontWeight.w500,
    );

    Widget digit(String label) => _PadKey(
      key: ValueKey('pin-key-$label'),
      onTap: widget.enabled ? () => _type(label) : null,
      semanticLabel: label,
      child: Text(label, style: digitStyle),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 3 * _PadKey.size + 6 * AnchorTokens.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            label: l10n.lockPinDigits(_pin.length),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 12,
                  children: [
                    for (var i = 0; i < math.max(_pin.length, 4); i++)
                      AnimatedContainer(
                        duration: context.motion(
                          AnchorTokens.motionDurationPress,
                        ),
                        width: AnchorTokens.space12,
                        height: AnchorTokens.space12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length
                              ? colors.accentStrong
                              : Colors.transparent,
                          border: Border.all(
                            color: i < _pin.length
                                ? colors.accentStrong
                                : colors.appMuted,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: context.density.space24),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final label in row) digit(label)],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PadKey(
                key: const ValueKey('pin-key-erase'),
                onTap: widget.enabled && _pin.isNotEmpty ? _erase : null,
                semanticLabel: l10n.lockPinErase,
                child: Icon(
                  LucideIcons.delete,
                  size: AnchorTokens.sizeIconLarge,
                  color: colors.appText,
                ),
              ),
              digit('0'),
              _PadKey(
                key: const ValueKey('pin-key-ok'),
                onTap: widget.enabled && _pin.isNotEmpty ? _submit : null,
                semanticLabel: l10n.commonOk,
                child: Text(
                  l10n.commonOk,
                  style: AppTypography.navTitle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _pin.isNotEmpty
                        ? colors.accentStrong
                        : colors.appMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    super.key,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String semanticLabel;

  static const double size = 72; // off-scale: a PIN pad key

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AnchorTokens.space4),
      child: Pressable(
        style: PressStyle.toolbar,
        onTap: onTap,
        semanticLabel: semanticLabel,
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Shakes its child sideways each time [trigger] changes: a wrong PIN or
/// pattern.
class ShakeOnChange extends StatefulWidget {
  const ShakeOnChange({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<ShakeOnChange> createState() => _ShakeOnChangeState();
}

class _ShakeOnChangeState extends State<ShakeOnChange>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Spring.smooth.duration,
  );

  @override
  void didUpdateWidget(ShakeOnChange old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      Haptics.warning();
      if (!context.isMotionReduced) _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * 12 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
