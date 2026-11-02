import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/l10n.dart';
import '../../data/live_host.dart';
import '../../data/live_signals.dart';
import '../../domain/live_image.dart';

/// Draws the live images in a note's text ([LiveImage]): the camera or
/// screen of the device that added one, straight from it, cropped and sized
/// as the note says. One this phone added shows its own camera, from
/// [LiveHost].
class LiveImageEmbedBuilder extends EmbedBuilder {
  const LiveImageEmbedBuilder({
    required this.signals,
    required this.host,
    required this.noteId,
    this.keepStill,
  });

  final LiveSignals Function() signals;
  final LiveHost Function() host;
  final String? Function() noteId;

  /// Adds a still of the video (PNG) to the note's attachments under
  /// `name`; null where the note can't be changed.
  final Future<void> Function(Uint8List png, String name)? keepStill;

  @override
  String get key => LiveImage.embedType;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final image = LiveImage.tryParse(embedContext.node.value.data);
    if (image == null) return const SizedBox.shrink();
    return _LiveImageView(
      key: ValueKey(image.id),
      image: image,
      controller: embedContext.controller,
      node: embedContext.node,
      noteId: noteId(),
      signals: signals(),
      host: host(),
      keepStill: embedContext.readOnly ? null : keepStill,
    );
  }
}

enum _Status {
  /// Asking the other device for the video.
  connecting,

  /// The other device doesn't answer: closed, asleep or offline.
  waiting,

  /// It answers but doesn't show its camera or screen right now.
  paused,

  /// This phone's own camera, turned off.
  off,
  live,
}

/// How soon to ask again while there is no video.
const _retryAfter = Duration(seconds: 5);

/// Without an answer by then, the other device is taken to be away.
const _waitingAfter = Duration(seconds: 8);

class _LiveImageView extends StatefulWidget {
  const _LiveImageView({
    super.key,
    required this.image,
    required this.controller,
    required this.node,
    required this.noteId,
    required this.signals,
    required this.host,
    required this.keepStill,
  });

  final LiveImage image;

  /// Where it is in the text, to keep it from being selected.
  final QuillController controller;
  final Embed node;
  final String? noteId;
  final LiveSignals signals;
  final LiveHost host;
  final Future<void> Function(Uint8List png, String name)? keepStill;

  @override
  State<_LiveImageView> createState() => _LiveImageViewState();
}

class _LiveImageViewState extends State<_LiveImageView>
    with SingleTickerProviderStateMixin {
  final _renderer = RTCVideoRenderer();
  final _tab = const Uuid().v4();
  final _session = const Uuid().v4();
  final _pending = <RTCIceCandidate>[];

  StreamSubscription<Map<String, dynamic>>? _messages;
  RTCPeerConnection? _pc;
  Map<String, dynamic>? _peer;
  bool _hasOffer = false;
  bool _isRendererReady = false;
  _Status _status = _Status.connecting;

  /// The other device's microphone: 'on', 'muted', or null for none.
  String? _mic;

  /// Sound starts off, as on the web; a tap turns it on.
  bool _isListening = false;

  /// How many watch it, as the device that shows it says; null until then.
  int? _viewers;

  /// Counts the stills kept, to flash the video for each.
  int _flashes = 0;

  /// When the last tap was, to tell a double tap.
  DateTime? _lastTap;

  /// The single tap's spin, waiting to see if a second tap follows.
  Timer? _pendingSpin;

  /// The sound controls, whose taps aren't the video's.
  final _controls = GlobalKey();

  static const _doubleTapWithin = Duration(milliseconds: 300);

  /// A tap on the video: it is claimed here, so the editor doesn't select
  /// the live image (typing would then replace it). A second tap soon after
  /// makes it a double tap.
  void _tapped(TapUpDetails details) {
    if (_isOnControls(details.globalPosition)) return;
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null && now.difference(last) < _doubleTapWithin) {
      _lastTap = null;
      _pendingSpin?.cancel();
      _deselect();
      if (widget.keepStill != null) unawaited(_keepStill());
      return;
    }
    _lastTap = now;
    _pendingSpin?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) return;
    _pendingSpin = Timer(_doubleTapWithin, () {
      if (mounted) unawaited(_spin.forward(from: 0));
    });
  }

  /// The editor selects the live image on a double tap (typing would then
  /// replace it): the caret goes just after it instead.
  void _deselect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = widget.node;
      if (!mounted || node.parent == null) return;
      final at = node.documentOffset;
      final selection = widget.controller.selection;
      if (selection.isCollapsed ||
          selection.start > at ||
          selection.end <= at) {
        return;
      }
      widget.controller.updateSelection(
        TextSelection.collapsed(offset: at + 1),
        ChangeSource.local,
      );
    });
  }

  bool _isOnControls(Offset position) {
    final box = _controls.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(position);
  }

  /// A tap spins the red dot into an anchor and back.
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Size _videoSize = Size.zero;
  Timer? _retry;
  Timer? _away;

  Map<String, dynamic> get _me => {'device': LiveSignals.device, 'tab': _tab};

  /// Added on this phone: shown from its own camera, not asked for.
  bool get _isOwn => widget.image.device == LiveSignals.device;

  bool _isFront = true;

  /// Follows this phone's camera for its own live image.
  void _ownChanged() {
    if (!mounted) return;
    final capture = widget.host.captureOf(widget.image.id);
    setState(() {
      if (_renderer.srcObject != capture?.stream) {
        _renderer.srcObject = capture?.stream;
      }
      _isFront = capture?.isFront ?? _isFront;
      _status = capture == null ? _Status.off : _Status.live;
      _mic = capture?.mic;
      _viewers = capture == null
          ? null
          : widget.host.viewersOf(widget.image.id);
    });
  }

  Future<void> _turnCameraOn() async {
    final noteId = widget.noteId;
    if (noteId == null) return;
    try {
      await widget.host.restart(widget.image.id, noteId, isFront: _isFront);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          context.l10n.liveImageCameraFailed,
          kind: SnackbarKind.error,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _renderer.onResize = () {
      if (!mounted) return;
      final value = _renderer.value;
      // A phone's camera reports its sensor's size, and a turn to show it.
      final isTurned = value.rotation == 90 || value.rotation == 270;
      setState(
        () => _videoSize = isTurned
            ? Size(value.height, value.width)
            : Size(value.width, value.height),
      );
    };
    unawaited(
      _renderer.initialize().then((_) {
        if (!mounted) return;
        setState(() => _isRendererReady = true);
        if (_isOwn) _ownChanged();
      }),
    );
    if (_isOwn) {
      widget.host.addListener(_ownChanged);
      return;
    }
    _messages = widget.signals.messages.listen(_receive);
    _ask();
  }

  @override
  void dispose() {
    widget.host.removeListener(_ownChanged);
    _pendingSpin?.cancel();
    _spin.dispose();
    final peer = _peer;
    if (peer != null) _send('bye', to: peer);
    _retry?.cancel();
    _away?.cancel();
    unawaited(_messages?.cancel());
    _close();
    _renderer.srcObject = null;
    unawaited(_renderer.dispose());
    super.dispose();
  }

  void _send(
    String kind, {
    Map<String, dynamic>? to,
    Map<String, dynamic>? data,
  }) {
    final noteId = widget.noteId;
    if (noteId == null) return;
    unawaited(
      widget.signals.send({
        'noteId': noteId,
        'liveId': widget.image.id,
        'kind': kind,
        'from': _me,
        'to': to ?? {'device': widget.image.device},
        'session': _session,
        'data': ?data,
      }),
    );
  }

  void _setStatus(_Status status) {
    if (mounted && status != _status) setState(() => _status = status);
  }

  /// Asks for the video until it comes, as the web app does.
  void _ask() {
    _retry?.cancel();
    if (!mounted) return;
    if (_status != _Status.live && _pc == null) _send('want');
    _retry = Timer(_retryAfter, _ask);
    if (_away == null && _status == _Status.connecting) {
      _away = Timer(_waitingAfter, () {
        _away = null;
        if (_status == _Status.connecting) _setStatus(_Status.waiting);
      });
    }
  }

  void _close() {
    unawaited(_pc?.close());
    _pc = null;
    _peer = null;
    _hasOffer = false;
    _pending.clear();
  }

  void _receive(Map<String, dynamic> message) {
    // From the server: the note was trashed or deleted.
    if (message['kind'] == 'stop') {
      if (message['noteId'] != widget.noteId) return;
      _close();
      _renderer.srcObject = null;
      _setStatus(_Status.paused);
      return;
    }
    if (message['liveId'] != widget.image.id ||
        message['noteId'] != widget.noteId) {
      return;
    }
    final from = message['from'];
    if (from is! Map<String, dynamic>) return;
    final kind = message['kind'];
    // "ready" goes to every device: the video is back.
    if (kind == 'ready') {
      if (_status != _Status.live) {
        _setStatus(_Status.connecting);
        _ask();
      }
      return;
    }
    final to = message['to'];
    if (to is! Map ||
        to['device'] != LiveSignals.device ||
        (to['tab'] != null && to['tab'] != _tab) ||
        message['session'] != _session) {
      return;
    }
    final data = message['data'];
    switch (kind) {
      case 'offer':
        if (data is Map) unawaited(_takeOffer(from, data).catchError((_) {}));
      case 'ice':
        if (data is! Map) return;
        final candidate = data['candidate'];
        if (candidate is! String || candidate.isEmpty) return;
        final ice = RTCIceCandidate(
          candidate,
          data['sdpMid'] as String?,
          (data['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_hasOffer) {
          unawaited(_pc?.addCandidate(ice).catchError((_) {}));
        } else {
          _pending.add(ice);
        }
      case 'viewers':
        final count = data is Map ? data['count'] : null;
        if (count is num && count >= 0 && mounted) {
          setState(() => _viewers = count.floor());
        }
      case 'mic':
        if (data is Map && mounted) {
          setState(() => _mic = _readMic(data['mic']));
        }
      case 'unavailable':
        if (_status != _Status.live) _setStatus(_Status.paused);
      case 'bye':
        _close();
        _renderer.srcObject = null;
        _setStatus(_Status.paused);
    }
  }

  Future<void> _takeOffer(Map<String, dynamic> from, Map data) async {
    final sdp = data['sdp'];
    if (sdp is! String) return;
    _close();
    _mic = _readMic(data['mic']);
    final pc = await createPeerConnection({
      'iceServers': await widget.signals.iceServers(),
      'sdpSemantics': 'unified-plan',
    });
    if (!mounted) {
      unawaited(pc.close());
      return;
    }
    _pc = pc;
    _peer = from;
    pc.onTrack = (event) {
      if (_pc != pc || event.streams.isEmpty) return;
      setState(() => _renderer.srcObject = event.streams.first);
      _applySound();
    };
    pc.onIceCandidate = (candidate) {
      final text = candidate.candidate;
      if (_pc != pc || text == null || text.isEmpty) return;
      _send(
        'ice',
        to: from,
        data: {
          'candidate': text,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };
    pc.onConnectionState = (state) {
      if (_pc != pc) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _setStatus(_Status.live);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _close();
          _setStatus(_Status.connecting);
          _ask();
        default:
      }
    };
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    _hasOffer = true;
    for (final candidate in [..._pending]) {
      await pc.addCandidate(candidate).catchError((_) {});
    }
    _pending.clear();
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    if (_pc != pc) return;
    _send('answer', to: from, data: {'type': answer.type, 'sdp': answer.sdp});
  }

  static String? _readMic(Object? value) =>
      value == 'on' || value == 'muted' ? value as String : null;

  /// Plays the other device's sound, or not.
  void _applySound() {
    for (final track in _renderer.srcObject?.getAudioTracks() ?? const []) {
      track.enabled = _isListening;
    }
  }

  Future<void> _toggleSound() async {
    setState(() => _isListening = !_isListening);
    // The loudspeaker, not the earpiece a call would use.
    if (_isListening) await Helper.setSpeakerphoneOn(true).catchError((_) {});
    _applySound();
  }

  /// A double tap keeps a still of what shows, its crop only, named for the
  /// moment it was taken (as an ISO 8601 time).
  Future<void> _keepStill() async {
    final keep = widget.keepStill;
    final track = _renderer.srcObject?.getVideoTracks().firstOrNull;
    if (keep == null || track == null) return;
    final l10n = context.l10n;
    final taken = DateTime.now().toUtc();
    setState(() => _flashes++);
    try {
      final frame = await track.captureFrame();
      final png = await _cropped(
        frame.asUint8List(),
        widget.image.crop ?? LiveCrop.whole,
      );
      await keep(png, '${_isoMilliseconds(taken)}.png');
      if (mounted) {
        AppSnackbar.show(
          context,
          l10n.liveImageStillKept,
          kind: SnackbarKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          l10n.liveImageStillFailed,
          kind: SnackbarKind.error,
        );
      }
    }
  }

  /// As the web app names its stills: UTC, to the millisecond.
  static String _isoMilliseconds(DateTime utc) => utc
      .toIso8601String()
      .replaceFirstMapped(RegExp(r'(\.\d{3})\d*Z$'), (match) => '${match[1]}Z');

  static Future<Uint8List> _cropped(Uint8List png, LiveCrop crop) async {
    if (crop == LiveCrop.whole) return png;
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final from = Rect.fromLTRB(
      crop.left * image.width,
      crop.top * image.height,
      crop.right * image.width,
      crop.bottom * image.height,
    );
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawImageRect(image, from, Offset.zero & from.size, Paint());
    final out = await recorder.endRecording().toImage(
      from.width.round(),
      from.height.round(),
    );
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    out.dispose();
    return bytes!.buffer.asUint8List();
  }

  String _statusText(BuildContext context) {
    final l10n = context.l10n;
    final who = widget.image.label ?? l10n.liveImageSomeDevice;
    return switch (_status) {
      _Status.connecting => l10n.liveImageConnecting(who),
      _Status.waiting => l10n.liveImageWaiting(who),
      _Status.paused =>
        widget.image.isScreen
            ? l10n.liveImageScreenPaused(who)
            : l10n.liveImageCameraPaused(who),
      _Status.off => l10n.liveImageCameraOff,
      _Status.live => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final radius = context.appStyle.corners(AnchorTokens.radiusTile);
    final crop = widget.image.crop ?? LiveCrop.whole;
    final isLive =
        _status == _Status.live &&
        _isRendererReady &&
        _renderer.srcObject != null;
    final aspect = _videoSize.width > 0 && _videoSize.height > 0
        ? (crop.across * _videoSize.width) / (crop.down * _videoSize.height)
        : 16 / 9;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * (widget.image.width ?? 1.0);
          final height = width / aspect;
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              label: widget.image.isScreen
                  ? l10n.liveImageScreen
                  : l10n.liveImageCamera,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: isLive ? _tapped : null,
                child: ClipRRect(
                  borderRadius: radius,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: colors.appText.withValues(alpha: 0.06),
                          ),
                        ),
                        if (_isRendererReady)
                          // Larger than the frame, so only the crop shows.
                          Positioned(
                            left: -crop.left / crop.across * width,
                            top: -crop.top / crop.down * height,
                            width: width / crop.across,
                            height: height / crop.down,
                            child: Opacity(
                              opacity: isLive ? 1 : 0,
                              child: RTCVideoView(
                                _renderer,
                                mirror: _isOwn && _isFront,
                              ),
                            ),
                          ),
                        if (!isLive)
                          Positioned.fill(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _statusText(context),
                                      textAlign: TextAlign.center,
                                      style: context.noteTypography.cardBody
                                          .withSize(
                                            13,
                                          ) // off-scale: a status line
                                          .copyWith(color: colors.appMuted),
                                    ),
                                    if (_status == _Status.off &&
                                        widget.keepStill != null) ...[
                                      const SizedBox(height: 10),
                                      AppButton(
                                        label: l10n.liveImageTurnCameraOn,
                                        icon: LucideIcons.camera,
                                        isExpanded: false,
                                        size: AppButtonSize.small,
                                        onPressed: () =>
                                            unawaited(_turnCameraOn()),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (isLive)
                          PositionedDirectional(
                            top: 8,
                            start: 8,
                            child: _LiveBadge(
                              label: l10n.liveImageBadge,
                              viewers: _viewers,
                              viewersLabel: _viewers == null
                                  ? null
                                  : l10n.liveImageViewers(_viewers!),
                              spin: _spin,
                            ),
                          ),
                        if (_flashes > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(_flashes),
                                tween: Tween(begin: 0.85, end: 0),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                builder: (context, opacity, _) => ColoredBox(
                                  color: Colors.white.withValues(
                                    alpha: opacity,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (isLive && _mic != null)
                          PositionedDirectional(
                            end: 8,
                            bottom: 8,
                            child: Row(
                              key: _controls,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_mic == 'muted' && !_isOwn)
                                  _RoundIcon(
                                    icon: LucideIcons.micOff,
                                    label: l10n.liveImageMicMuted,
                                    isWarning: true,
                                  ),
                                const SizedBox(width: 6),
                                if (_isOwn)
                                  _RoundIcon(
                                    icon: _mic == 'on'
                                        ? LucideIcons.mic
                                        : LucideIcons.micOff,
                                    label: _mic == 'on'
                                        ? l10n.liveImageMute
                                        : l10n.liveImageUnmute,
                                    onTap: () => widget.host.setMicMuted(
                                      widget.image.id,
                                      _mic == 'on',
                                    ),
                                  )
                                else
                                  _RoundIcon(
                                    icon: _isListening
                                        ? LucideIcons.volume2
                                        : LucideIcons.volumeX,
                                    label: _isListening
                                        ? l10n.liveImageSoundOff
                                        : l10n.liveImageSoundOn,
                                    onTap: () => unawaited(_toggleSound()),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A round control or marker over the video.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.label,
    this.onTap,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final circle = DecoratedBox(
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xD9DC2626)
            : Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Icon(
          icon,
          size: AnchorTokens.sizeIconSmall,
          color: Colors.white,
        ),
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return Semantics(label: label, child: circle);
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // A larger target than it looks.
          child: Padding(padding: const EdgeInsets.all(4), child: circle),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.label,
    required this.viewers,
    required this.viewersLabel,
    required this.spin,
  });

  final String label;
  final int? viewers;
  final String? viewersLabel;
  final Animation<double> spin;

  static const _red = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final style = context.noteTypography.cardBody
        .withSize(10) // off-scale: a badge
        .copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        );
    final viewers = this.viewers;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SpinningMark(spin: spin),
            const SizedBox(width: 5),
            Text(label.toUpperCase(), style: style),
            if (viewers != null) ...[
              Container(
                width: 1,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white.withValues(alpha: 0.35),
              ),
              Semantics(
                label: viewersLabel,
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.eye, size: 11, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      '$viewers',
                      style: style.copyWith(
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The red dot; a tap spins it twice, turning it into an anchor halfway
/// and back, as on the web (editor.css, live-spin).
class _SpinningMark extends StatelessWidget {
  const _SpinningMark({required this.spin});

  final Animation<double> spin;

  /// 0 to 1 by 28% of the way, 1 until 72%, back to 0 at the end.
  static double _anchorShare(double t) {
    const edge = 0.28;
    final share = t < edge
        ? t / edge
        : t > 1 - edge
        ? (1 - t) / edge
        : 1.0;
    return Curves.easeInOut.transform(share.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 10,
      child: AnimatedBuilder(
        animation: spin,
        builder: (context, _) {
          final t = spin.value;
          final turn = const Cubic(0.45, 0, 0.25, 1).transform(t);
          final grow = 1 + 0.9 * math.sin(math.pi * t);
          final anchor = _anchorShare(t);
          return Transform.rotate(
            angle: turn * 4 * math.pi,
            child: Transform.scale(
              scale: grow,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Transform.scale(
                    scale: 1 - anchor,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: _LiveBadge._red,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 6),
                    ),
                  ),
                  if (anchor > 0)
                    Opacity(
                      opacity: anchor,
                      child: Transform.scale(
                        scale: anchor,
                        child: const Icon(
                          LucideIcons.anchor,
                          size: 11,
                          color: _LiveBadge._red,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
