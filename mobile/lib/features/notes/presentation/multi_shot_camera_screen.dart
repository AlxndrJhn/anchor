import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/motion/haptics.dart';
import '../../../core/motion/springs.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/system_bars.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/page_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';

/// Takes pictures one after another without going back to the note: each
/// shot flies into the pile in the corner, and goes to [onPicture] at once,
/// so none is lost if the app is closed. Done (or Back) returns how many
/// were taken, once the last has been handed over.
class MultiShotCameraScreen extends StatefulWidget {
  final Future<void> Function(XFile picture) onPicture;

  const MultiShotCameraScreen({super.key, required this.onPicture});

  static Future<int> open(
    BuildContext context, {
    required Future<void> Function(XFile picture) onPicture,
  }) async {
    final count = await Navigator.of(context, rootNavigator: true).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
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
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _camera;
  bool _isOpening = false;
  _CameraProblem? _problem;
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
      AppLogger.instance.warn(LogTags.attachments, 'No cameras: $e');
    }
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _problem = _CameraProblem.noCamera);
      return;
    }
    final back = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _cameraIndex = back < 0 ? 0 : back;
    await _open();
  }

  Future<void> _open() async {
    if (_cameras.isEmpty || _isOpening) return;
    _isOpening = true;
    try {
      await _openCamera();
    } finally {
      _isOpening = false;
    }
  }

  Future<void> _openCamera() async {
    final camera = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await camera.initialize();
      await camera.setFlashMode(_flash);
    } on CameraException catch (e) {
      await camera.dispose();
      if (!mounted) return;
      setState(
        () => _problem = e.code.contains('Access')
            ? _CameraProblem.noPermission
            : _CameraProblem.failed,
      );
      return;
    }
    if (!mounted) {
      await camera.dispose();
      return;
    }
    setState(() {
      _camera = camera;
      _problem = null;
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
    Haptics.medium();
    try {
      final shot = await camera.takePicture();
      if (!mounted) return;
      _flashFade.forward(from: 0);
      _flyIntoPile(shot.path);
      _handing = _handing.then((_) => _hand(shot));
    } on CameraException catch (e) {
      AppLogger.instance.warn(
        LogTags.attachments,
        'Couldn’t take a picture: $e',
      );
    } finally {
      if (mounted) setState(() => _isShooting = false);
    }
  }

  Future<void> _hand(XFile shot) async {
    try {
      await widget.onPicture(shot);
    } catch (e) {
      AppLogger.instance.warn(
        LogTags.attachments,
        'Couldn’t keep a picture: $e',
      );
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
    if (from == null || to == null || context.isMotionReduced) {
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
    final l10n = context.l10n;
    const ink = AnchorTokens.colorMediaText;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Material(
        color: Colors.black,
        child: Stack(
          key: _stackKey,
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  PageBar(
                    color: Colors.black,
                    systemBars: systemBarsStyle(dark: true),
                    leading: BarButton(
                      icon: LucideIcons.x,
                      label: l10n.commonClose,
                      color: ink,
                      onPressed: _finish,
                    ),
                    actions: [
                      if (_camera != null)
                        BarButton(
                          icon: _flash == FlashMode.off
                              ? LucideIcons.zapOff
                              : LucideIcons.zap,
                          label: _flash == FlashMode.off
                              ? l10n.cameraFlashOff
                              : l10n.cameraFlashOn,
                          color: ink,
                          onPressed: _toggleFlash,
                        ),
                    ],
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
                      24,
                      context.density.space16,
                      24,
                      MediaQuery.paddingOf(context).bottom +
                          context.density.space24,
                    ),
                    child: _buildControls(),
                  ),
                ],
              ),
            ),
            // The white of a shutter going off.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashFade,
                builder: (context, _) => _flashFade.isAnimating
                    ? ColoredBox(
                        color: ink.withValues(
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
                color: AnchorTokens.colorMediaShadeStrong,
                child: Center(child: CircularProgressIndicator(color: ink)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final camera = _camera;
    final l10n = context.l10n;
    if (_problem case final problem?) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: context.density.space12,
          children: [
            const Icon(
              LucideIcons.cameraOff,
              color: AnchorTokens.colorMediaMuted,
              size: AnchorTokens.sizeIconLarge,
            ),
            Text(
              switch (problem) {
                _CameraProblem.noCamera => l10n.cameraNone,
                _CameraProblem.noPermission => l10n.cameraNoPermission,
                _CameraProblem.failed => l10n.cameraFailed,
              },
              textAlign: TextAlign.center,
              style: AppTypography.secondary.copyWith(
                color: AnchorTokens.colorMediaMuted,
              ),
            ),
          ],
        ),
      );
    }
    if (camera == null || !camera.value.isInitialized) {
      return const CircularProgressIndicator(
        color: AnchorTokens.colorMediaMuted,
      );
    }
    return ClipRRect(
      borderRadius: context.appStyle.corners(AnchorTokens.radiusLg),
      child: CameraPreview(camera),
    );
  }

  Widget _buildControls() {
    final count = _shots.length;
    final l10n = context.l10n;
    return Row(
      children: [
        SizedBox.square(
          dimension: _sideSize,
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
        SizedBox.square(
          dimension: _sideSize,
          child: count > 0
              ? _RoundButton(
                  icon: LucideIcons.check,
                  label: l10n.commonDone,
                  isFilled: true,
                  onTap: _finish,
                )
              : _cameras.length > 1
              ? _RoundButton(
                  icon: LucideIcons.switchCamera,
                  label: l10n.cameraSwitch,
                  onTap: _switchCamera,
                )
              : null,
        ),
      ],
    );
  }
}

/// The pile's and the round buttons' square, beside the shutter.
const double _sideSize = 64; // off-scale: camera controls

enum _CameraProblem { noCamera, noPermission, failed }

/// The big round button that takes the picture; it dips when pressed.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.isEnabled, required this.onTap});

  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = AnchorTokens.colorMediaText;
    return Pressable(
      style: PressStyle.button,
      onTap: isEnabled ? onTap : null,
      semanticLabel: context.l10n.cameraShutter,
      child: Container(
        width: 76, // off-scale: the shutter
        height: 76, // off-scale: as above
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ink, width: 4),
        ),
        child: AnimatedContainer(
          duration: context.motion(AnchorTokens.motionDurationPress),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEnabled ? ink : ink.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

/// The pictures taken so far: the last one, with how many there are.
class _Pile extends StatelessWidget {
  const _Pile({required this.last, required this.count, required this.bump});

  final String? last;
  final int count;
  final Animation<double> bump;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final radius = context.appStyle.corners(AnchorTokens.radiusTile);
    if (last == null) return const SizedBox.shrink();
    return Semantics(
      label: context.l10n.cameraTaken(count),
      child: AnimatedBuilder(
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
                      color: AnchorTokens.colorMediaControlHover,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accentStrong,
                  borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    '$count',
                    style: AppTypography.footnote.tabular.copyWith(
                      color: AnchorTokens.colorMediaText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shot shrinking from the preview into the pile, turning as it goes.
class _FlyingShot extends StatelessWidget {
  const _FlyingShot({
    required this.path,
    required this.from,
    required this.to,
    required this.animation,
  });

  final String path;
  final Rect from;
  final Rect to;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final radius = context.appStyle.corners(AnchorTokens.radiusTile);
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
            borderRadius: radius,
            border: Border.all(color: AnchorTokens.colorMediaText, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AnchorTokens.colorMediaShadeStrong,
                blurRadius: 12,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Image.file(File(path), fit: BoxFit.cover, cacheWidth: 720),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isFilled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Pressable(
        style: PressStyle.button,
        onTap: () {
          Haptics.light();
          onTap();
        },
        semanticLabel: label,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? AnchorTokens.colorMediaText
                : AnchorTokens.colorMediaControl,
          ),
          child: Icon(
            icon,
            size: AnchorTokens.sizeIconMedium,
            color: isFilled
                ? AnchorTokens.colorMediaScrim
                : AnchorTokens.colorMediaText,
          ),
        ),
      ),
    );
  }
}
