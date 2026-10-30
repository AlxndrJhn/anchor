import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/app_icon_sizes.dart';

/// Takes pictures one after another without going back to the note: each
/// shot flies into the pile in the corner, and goes to [onPicture] at once,
/// so none is lost if the app is closed. Done (or Back) returns how many
/// were taken, once the last has been handed over.
class MultiShotCameraScreen extends StatefulWidget {
  static const routeName = 'multi-shot camera';

  final Future<void> Function(XFile picture) onPicture;

  const MultiShotCameraScreen({super.key, required this.onPicture});

  static Future<int> open(
    BuildContext context, {
    required Future<void> Function(XFile picture) onPicture,
  }) async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        settings: const RouteSettings(name: routeName),
        builder: (_) => MultiShotCameraScreen(onPicture: onPicture),
      ),
    );
    return count ?? 0;
  }

  @override
  State<MultiShotCameraScreen> createState() => _MultiShotCameraScreenState();
}

class _MultiShotCameraScreenState extends State<MultiShotCameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _tag = 'Camera';

  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _camera;
  bool _isOpening = false;
  String? _error;
  bool _isShooting = false;
  bool _isLeaving = false;
  FlashMode _flash = FlashMode.off;

  final _shots = <String>[];

  /// Hands the shots over one at a time, in the order they were taken.
  Future<void> _handing = Future.value();

  final _stackKey = GlobalKey();
  final _previewKey = GlobalKey();
  final _pileKey = GlobalKey();

  late final _flashFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// The shot flying into the pile, and where it starts and lands.
  String? _flying;
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flight.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _flying = null);
        _bump.forward(from: 0);
      }
    });
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLogger.instance.info(_tag, 'Closed, ${_shots.length} taken');
    _camera?.dispose();
    _flashFade.dispose();
    _flight.dispose();
    _bump.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is the system's; let go of it while away.
    final camera = _camera;
    AppLogger.instance.info(
      _tag,
      'App ${state.name}, camera ${camera == null ? 'closed' : 'open'}',
    );
    if (state == AppLifecycleState.inactive) {
      _camera = null;
      camera?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && camera == null) {
      // Also back from the permission prompt, which a first open waits on.
      _open();
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      AppLogger.instance.warn(_tag, 'No cameras: $e');
    }
    AppLogger.instance.info(
      _tag,
      'Cameras: ${_cameras.map((c) => '${c.name} ${c.lensDirection.name}').join(', ')}',
    );
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _error = 'No camera found');
      return;
    }
    final back = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _cameraIndex = back < 0 ? 0 : back;
    await _open();
  }

  Future<void> _open() async {
    if (_cameras.isEmpty) return;
    if (_isOpening) {
      AppLogger.instance.info(_tag, 'Already opening, not opening again');
      return;
    }
    _isOpening = true;
    try {
      await _openCamera();
    } finally {
      _isOpening = false;
    }
  }

  Future<void> _openCamera() async {
    final description = _cameras[_cameraIndex];
    AppLogger.instance.info(_tag, 'Opening ${description.name}');
    final opening = Stopwatch()..start();
    final camera = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await camera.initialize();
      await camera.setFlashMode(_flash);
    } on CameraException catch (e) {
      AppLogger.instance.warn(
        _tag,
        'Couldn’t open ${description.name} after '
        '${opening.elapsedMilliseconds} ms: ${e.code} ${e.description}',
      );
      await camera.dispose();
      if (!mounted) return;
      setState(
        () => _error = e.code.contains('Access')
            ? 'Anchor needs the camera permission to take pictures'
            : 'Couldn’t start the camera',
      );
      return;
    } catch (e) {
      AppLogger.instance.warn(
        _tag,
        'Couldn’t open ${description.name} after '
        '${opening.elapsedMilliseconds} ms: $e',
      );
      rethrow;
    }
    final value = camera.value;
    AppLogger.instance.info(
      _tag,
      'Opened ${description.name} in ${opening.elapsedMilliseconds} ms: '
      'preview ${value.previewSize}, initialized ${value.isInitialized}, '
      'preview paused ${value.isPreviewPaused}',
    );
    if (!mounted) {
      AppLogger.instance.info(_tag, 'Screen gone, closing the camera');
      await camera.dispose();
      return;
    }
    // Errors once running, such as the camera being taken away.
    String? lastError;
    camera.addListener(() {
      final error = camera.value.errorDescription;
      if (error != null && error != lastError) {
        AppLogger.instance.warn(_tag, '${description.name}: $error');
      }
      lastError = error;
    });
    setState(() {
      _camera = camera;
      _error = null;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final old = _camera;
    setState(() {
      _camera = null;
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    await old?.dispose();
    await _open();
  }

  Future<void> _toggleFlash() async {
    final next = _flash == FlashMode.off ? FlashMode.always : FlashMode.off;
    setState(() => _flash = next);
    try {
      await _camera?.setFlashMode(next);
    } on CameraException catch (_) {}
  }

  Future<void> _shoot() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _isShooting) return;
    setState(() => _isShooting = true);
    HapticFeedback.mediumImpact();
    try {
      final shot = await camera.takePicture();
      if (!mounted) return;
      _flashFade.forward(from: 0);
      _flyIntoPile(shot.path);
      _handing = _handing.then((_) => _hand(shot));
    } on CameraException catch (e) {
      AppLogger.instance.warn(_tag, 'Couldn’t take a picture: $e');
    } finally {
      if (mounted) setState(() => _isShooting = false);
    }
  }

  Future<void> _hand(XFile shot) async {
    try {
      await widget.onPicture(shot);
    } catch (e) {
      AppLogger.instance.warn(_tag, 'Couldn’t keep a picture: $e');
    }
  }

  void _flyIntoPile(String path) {
    final from = _rectOf(_previewKey);
    final to = _rectOf(_pileKey);
    setState(() {
      _shots.add(path);
      _flying = path;
      _from = from;
      _to = to;
    });
    if (from == null || to == null || MediaQuery.disableAnimationsOf(context)) {
      _flight.value = 1;
      setState(() => _flying = null);
      return;
    }
    _flight.forward(from: 0);
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: stack);
    return topLeft & box.size;
  }

  Future<void> _finish() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    await _handing;
    if (mounted) Navigator.of(context).pop(_shots.length);
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          key: _stackKey,
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      flash: _flash,
                      canFlash: _camera != null,
                      onClose: _finish,
                      onFlash: _toggleFlash,
                    ),
                    Expanded(
                      child: Center(
                        child: KeyedSubtree(
                          key: _previewKey,
                          child: _buildPreview(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        dims.xl,
                        dims.lg,
                        dims.xl,
                        dims.xl,
                      ),
                      child: _buildControls(),
                    ),
                  ],
                ),
              ),
            ),
            // The white of a shutter going off.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashFade,
                builder: (context, _) => _flashFade.isAnimating
                    ? ColoredBox(
                        color: Colors.white.withValues(
                          alpha: 0.6 * (1 - _flashFade.value),
                        ),
                        child: const SizedBox.expand(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (_flying != null && _from != null && _to != null)
              _FlyingShot(
                path: _flying!,
                from: _from!,
                to: _to!,
                animation: _flight,
              ),
            if (_isLeaving)
              const ColoredBox(
                color: Color(0x88000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final camera = _camera;
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.all(context.dims.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cameraOff, color: Colors.white70, size: 40),
            SizedBox(height: context.dims.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    if (camera == null || !camera.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white54);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CameraPreview(camera),
    );
  }

  Widget _buildControls() {
    final count = _shots.length;
    return Row(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: KeyedSubtree(
            key: _pileKey,
            child: _Pile(
              last: _flying == null
                  ? (count > 0 ? _shots.last : null)
                  : (count > 1 ? _shots[count - 2] : null),
              count: _flying == null ? count : count - 1,
              bump: _bump,
            ),
          ),
        ),
        const Spacer(),
        _Shutter(
          isEnabled: _camera != null && !_isShooting && !_isLeaving,
          onTap: _shoot,
        ),
        const Spacer(),
        SizedBox(
          width: 64,
          height: 64,
          child: count > 0
              ? _RoundButton(
                  icon: LucideIcons.check,
                  tooltip: 'Done',
                  filled: true,
                  onTap: _finish,
                )
              : _cameras.length > 1
              ? _RoundButton(
                  icon: LucideIcons.switchCamera,
                  tooltip: 'Switch camera',
                  onTap: _switchCamera,
                )
              : null,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final FlashMode flash;
  final bool canFlash;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  const _TopBar({
    required this.flash,
    required this.canFlash,
    required this.onClose,
    required this.onFlash,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.dims.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white),
            tooltip: 'Close',
            onPressed: onClose,
          ),
          const Spacer(),
          if (canFlash)
            IconButton(
              icon: Icon(
                flash == FlashMode.off ? LucideIcons.zapOff : LucideIcons.zap,
                color: Colors.white,
              ),
              tooltip: flash == FlashMode.off ? 'Flash off' : 'Flash on',
              onPressed: onFlash,
            ),
        ],
      ),
    );
  }
}

/// The big round button that takes the picture; it dips when pressed.
class _Shutter extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const _Shutter({required this.isEnabled, required this.onTap});

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take a picture',
      child: GestureDetector(
        onTapDown: widget.isEnabled
            ? (_) => setState(() => _isDown = true)
            : null,
        onTapUp: widget.isEnabled
            ? (_) => setState(() => _isDown = false)
            : null,
        onTapCancel: () => setState(() => _isDown = false),
        onTap: widget.isEnabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _isDown ? 0.88 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isEnabled ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pictures taken so far: the last one, with how many there are.
class _Pile extends StatelessWidget {
  final String? last;
  final int count;
  final Animation<double> bump;

  const _Pile({required this.last, required this.count, required this.bump});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (last == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: bump,
      builder: (context, child) {
        // Swells a little as a shot lands, then settles.
        final t = Curves.easeOut.transform(bump.value);
        final scale = 1 + 0.18 * (1 - (2 * t - 1).abs());
        return Transform.scale(scale: scale, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (count > 1)
            Positioned.fill(
              child: Transform.rotate(
                angle: -0.12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(last!),
                fit: BoxFit.cover,
                cacheWidth: 192,
                gaplessPlayback: true,
              ),
            ),
          ),
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 24),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A shot shrinking from the preview into the pile, turning as it goes.
class _FlyingShot extends StatelessWidget {
  final String path;
  final Rect from;
  final Rect to;
  final Animation<double> animation;

  const _FlyingShot({
    required this.path,
    required this.from,
    required this.to,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(animation.value);
        final rect = Rect.lerp(from, to, t)!;
        return Positioned.fromRect(
          rect: rect,
          child: Transform.rotate(angle: -0.12 * t, child: child),
        );
      },
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(path), fit: BoxFit.cover, cacheWidth: 720),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: filled ? theme.colorScheme.primary : Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                icon,
                size: AppIconSizes.lg,
                color: filled ? theme.colorScheme.onPrimary : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
