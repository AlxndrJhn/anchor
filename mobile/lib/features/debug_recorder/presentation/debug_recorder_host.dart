import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../core/motion/haptics.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';
import '../data/debug_recorder_controller.dart';
import '../data/debug_report.dart';
import 'debug_player_screen.dart';

/// Debug mode around the whole app. Two fingers held still for
/// [holdDuration] start filming it; the camera in the top left corner, or
/// [DebugRecorder.maxDuration], stop it, and the player opens.
///
/// Goes in `MaterialApp.builder`. It watches touches without taking them,
/// and the camera sits outside what's filmed.
class DebugRecorderHost extends ConsumerStatefulWidget {
  const DebugRecorderHost({super.key, required this.child});

  final Widget? child;

  static const holdDuration = Duration(seconds: 3);

  /// How far a held finger may drift, in logical pixels.
  static const holdSlop = 24.0;

  @override
  ConsumerState<DebugRecorderHost> createState() => _DebugRecorderHostState();
}

class _DebugRecorderHostState extends ConsumerState<DebugRecorderHost> {
  final _boundary = GlobalKey();
  final _recorder = DebugRecorder.instance;

  /// Where each finger on the screen went down.
  final _pointers = <int, Offset>{};
  Timer? _hold;
  GoRouter? _router;

  @override
  void dispose() {
    _hold?.cancel();
    _router?.routerDelegate.removeListener(_recordRoute);
    super.dispose();
  }

  void _onDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    _recordPointer('down', event);
    _hold?.cancel();
    _hold = null;
    if (_pointers.length == 2 && _recorder.status == DebugRecorderStatus.idle) {
      _hold = Timer(DebugRecorderHost.holdDuration, _start);
    }
  }

  void _onMove(PointerMoveEvent event) {
    final start = _pointers[event.pointer];
    if (_hold != null &&
        start != null &&
        (event.position - start).distance > DebugRecorderHost.holdSlop) {
      _hold!.cancel();
      _hold = null;
    }
  }

  void _onUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    _recordPointer(event is PointerCancelEvent ? 'cancel' : 'up', event);
    _hold?.cancel();
    _hold = null;
  }

  void _recordPointer(String action, PointerEvent event) {
    if (!_recorder.isRecording) return;
    _recorder.record('pointer', {
      'action': action,
      'pointer': event.pointer,
      'x': double.parse(event.position.dx.toStringAsFixed(1)),
      'y': double.parse(event.position.dy.toStringAsFixed(1)),
      'pointers': _pointers.length,
    });
  }

  void _start() {
    _hold = null;
    if (_pointers.length != 2) return;
    Haptics.heavy();
    final router = ref.read(goRouterProvider);
    _router = router;
    _recorder.start(
      boundary: () {
        final box = _boundary.currentContext?.findRenderObject();
        return box is RenderRepaintBoundary ? box : null;
      },
      onFinished: _review,
    );
    _recordRoute();
    router.routerDelegate.addListener(_recordRoute);
    _recorder.record('screen', {
      'width': MediaQuery.sizeOf(context).width,
      'height': MediaQuery.sizeOf(context).height,
      'pixel_ratio': MediaQuery.devicePixelRatioOf(context),
      'brightness': Theme.of(context).brightness.name,
    });
  }

  void _recordRoute() {
    final router = _router;
    if (router == null) return;
    _recorder.record('route', {
      'location': router.routerDelegate.currentConfiguration.uri.toString(),
    });
  }

  void _stop() {
    Haptics.medium();
    _recorder.stop(_review);
  }

  void _review(DebugRecording recording) {
    _router?.routerDelegate.removeListener(_recordRoute);
    final navigator = _router?.routerDelegate.navigatorKey.currentState;
    if (navigator == null || !mounted) {
      _recorder.finishReview();
      return;
    }
    navigator
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => DebugPlayerScreen(recording: recording),
          ),
        )
        .whenComplete(_recorder.finishReview);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _recorder,
      builder: (context, app) => Stack(
        fit: StackFit.passthrough,
        children: [
          app!,
          if (_recorder.isRecording)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: MediaQuery.paddingOf(context).left + 8,
              child: _RecordingButton(onStop: _stop),
            ),
        ],
      ),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onUp,
        child: RepaintBoundary(
          key: _boundary,
          child: widget.child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The camera in the corner while filming: a red dot, a ring for the time
/// left, and a tap to stop.
class _RecordingButton extends StatefulWidget {
  const _RecordingButton({required this.onStop});

  final VoidCallback onStop;

  @override
  State<_RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<_RecordingButton>
    with SingleTickerProviderStateMixin {
  static const _size = 44.0;

  late final _progress = AnimationController(
    vsync: this,
    duration: DebugRecorder.maxDuration,
  )..forward();

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final red = colors.statusDanger;
    return Pressable(
      style: PressStyle.button,
      onTap: widget.onStop,
      semanticLabel: context.l10n.debugStopRecording,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: colors.appSurface,
          shape: BoxShape.circle,
          boxShadow: colors.shadowFab,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => CustomPaint(
                size: const Size.square(
                  _size - 4,
                ), // off-scale: inside the edge
                painter: _TimeLeftPainter(
                  left: 1 - _progress.value,
                  color: red,
                ),
              ),
            ),
            Icon(
              LucideIcons.video,
              size: AnchorTokens.sizeIconMedium,
              color: colors.appText,
            ),
            Positioned(
              top: 9, // off-scale: the dot on the camera
              right: 9, // off-scale: as above
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: red, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ring of time left, from the top, clockwise.
class _TimeLeftPainter extends CustomPainter {
  const _TimeLeftPainter({required this.left, required this.color});

  final double left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.5;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * left,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TimeLeftPainter old) =>
      old.left != left || old.color != color;
}
