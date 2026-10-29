import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/springs.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';

enum PressStyle {
  row(tint: 0.06),
  menuItem(tint: 0.07),
  barButton(tint: 0.09),
  toolbar(tint: 0.1),
  inverse(tint: 0.12),
  button(scale: 0.97),
  bottomBar(scale: 0.92),
  thumb(scale: 0.96),
  profileCard(scale: 0.985),
  plain(opacity: 0.55);

  const PressStyle({this.tint = 0, this.scale = 1, this.opacity = 1});

  final double tint;
  final double scale;
  final double opacity;
}

abstract final class DisabledOpacity {
  static const double icon = 0.35;
  static const double button = 0.4;
  static const double row = 0.45;
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.style,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.tintRadius,
    this.semanticLabel,
    this.isButton = true,
    this.selected,
    this.toggled,
    this.minSize,
    this.hitPadding,
  });

  final PressStyle style;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final BorderRadius? tintRadius;

  final String? semanticLabel;
  final bool isButton;
  final bool? selected;
  final bool? toggled;

  /// Grows the hit area without growing the drawing.
  final Size? minSize;

  final EdgeInsets? hitPadding;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _isPressed = false;
  final Stopwatch _pressed = Stopwatch();
  Timer? _release;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  void _set(bool down) {
    _release?.cancel();
    if (down) {
      _pressed
        ..reset()
        ..start();
    }
    if (_isPressed != down && mounted) setState(() => _isPressed = down);
  }

  void _lift() {
    final left = AnchorTokens.motionDurationPress - _pressed.elapsed;
    if (left <= Duration.zero) return _set(false);
    _release = Timer(left, () => _set(false));
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    Widget child = widget.child;
    if (style.tint > 0) {
      final tintColor = style == PressStyle.inverse
          ? context.anchor.appOnInverse
          : context.anchor.appText;
      child = AnimatedContainer(
        duration: context.motion(AnchorTokens.motionDurationPress),
        decoration: BoxDecoration(
          borderRadius:
              widget.tintRadius ??
              BorderRadius.circular(AnchorTokens.radiusPill),
          color: tintColor.withValues(alpha: _isPressed ? style.tint : 0),
        ),
        child: child,
      );
    }
    if (style.scale < 1 && !context.isMotionReduced) {
      child = AnimatedScale(
        scale: _isPressed ? style.scale : 1,
        duration: Spring.snappy.duration,
        curve: _isPressed
            ? AnchorTokens.motionEaseStandard
            : Spring.snappy.curve,
        child: child,
      );
    }
    if (style.opacity < 1) {
      child = AnimatedOpacity(
        opacity: _isPressed ? style.opacity : 1,
        duration: context.motion(AnchorTokens.motionDurationPress),
        child: child,
      );
    }
    if (widget.minSize != null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minSize!.width,
          minHeight: widget.minSize!.height,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      );
    }
    if (widget.hitPadding case final padding?) {
      child = Padding(padding: padding, child: child);
    }
    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _set(true) : null,
        onTapUp: _enabled ? (_) => _lift() : null,
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPressStart: widget.onLongPress == null
            ? null
            : (_) => _set(false),
        onLongPress: widget.onLongPress,
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          enabled: _enabled,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap?.call();
                return null;
              },
            ),
          },
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          child: child,
        ),
      ),
    );
  }
}
