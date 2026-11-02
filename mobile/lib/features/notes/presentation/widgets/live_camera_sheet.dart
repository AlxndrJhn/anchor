import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_sheet.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../l10n/l10n.dart';
import '../../data/live_host.dart';

/// The camera a new live image shows, chosen in [showLiveCameraSheet].
typedef LiveCameraChoice = ({MediaStream stream, bool isFront});

/// Chooses the front or back camera for a live image, with a preview, and
/// whether its microphone goes along. The stream is handed over on Add;
/// otherwise it is stopped.
Future<LiveCameraChoice?> showLiveCameraSheet(BuildContext context) {
  return showAnchorSheet<LiveCameraChoice>(
    context,
    semanticLabel: context.l10n.liveCameraTitle,
    builder: (_) => const _LiveCameraSheet(),
  );
}

class _LiveCameraSheet extends StatefulWidget {
  const _LiveCameraSheet();

  @override
  State<_LiveCameraSheet> createState() => _LiveCameraSheetState();
}

class _LiveCameraSheetState extends State<_LiveCameraSheet> {
  final _preview = RTCVideoRenderer();
  MediaStream? _stream;
  bool _isFront = false;
  bool _withMic = false;
  bool _isOpening = true;
  bool _isAdding = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_preview.initialize().then((_) => _open()));
  }

  @override
  void dispose() {
    _stopPreview();
    unawaited(_preview.dispose());
    super.dispose();
  }

  void _stopPreview() {
    final stream = _stream;
    _stream = null;
    _preview.srcObject = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      unawaited(track.stop());
    }
    unawaited(stream.dispose());
  }

  Future<void> _open() async {
    _stopPreview();
    setState(() {
      _isOpening = true;
      _failed = false;
    });
    try {
      final stream = await LiveHost.openCamera(
        isFront: _isFront,
        withMic: false,
      );
      if (!mounted) {
        for (final track in stream.getTracks()) {
          unawaited(track.stop());
        }
        return;
      }
      _stream = stream;
      _preview.srcObject = stream;
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _isOpening = false);
  }

  Future<void> _add() async {
    final stream = _stream;
    if (stream == null) return;
    setState(() => _isAdding = true);
    try {
      if (_withMic) {
        final voice = await navigator.mediaDevices.getUserMedia({
          'audio': true,
        });
        for (final track in voice.getAudioTracks()) {
          await stream.addTrack(track);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAdding = false;
          _withMic = false;
        });
      }
      return;
    }
    // Now the note's; closing mustn't stop it.
    _stream = null;
    _preview.srcObject = null;
    if (mounted) {
      Navigator.of(
        context,
      ).pop<LiveCameraChoice>((stream: stream, isFront: _isFront));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.anchor;
    final radius = context.appStyle.corners(AnchorTokens.radiusTile);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: l10n.liveCameraTitle,
            subtitle: l10n.liveCameraSubtitle,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: radius,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: Colors.black,
                      child: _failed
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  l10n.liveCameraNoCamera,
                                  textAlign: TextAlign.center,
                                  style: context.noteTypography.cardBody
                                      .withSize(13) // off-scale: a status line
                                      .copyWith(color: Colors.white70),
                                ),
                              ),
                            )
                          : _isOpening
                          ? const SizedBox.shrink()
                          : RTCVideoView(
                              _preview,
                              mirror: _isFront,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final (front, label) in [
                      (false, l10n.liveCameraBack),
                      (true, l10n.liveCameraFront),
                    ]) ...[
                      Expanded(
                        child: AppButton(
                          label: label,
                          size: AppButtonSize.medium,
                          kind: _isFront == front
                              ? AppButtonKind.primary
                              : AppButtonKind.secondary,
                          // The chosen one stays lit, not greyed out.
                          onPressed: _isAdding
                              ? null
                              : () {
                                  if (_isFront == front) return;
                                  setState(() => _isFront = front);
                                  unawaited(_open());
                                },
                        ),
                      ),
                      if (!front) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _withMic,
                  onChanged: _isAdding
                      ? null
                      : (on) => setState(() => _withMic = on),
                  secondary: Icon(LucideIcons.mic, color: colors.appMuted),
                  title: Text(l10n.liveCameraMic),
                  subtitle: Text(l10n.liveCameraMicHint),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: l10n.liveCameraAdd,
                  icon: LucideIcons.radio,
                  isBusy: _isAdding,
                  onPressed: _stream == null || _isAdding
                      ? null
                      : () => unawaited(_add()),
                ),
              ],
            ),
          ),
          const SheetBottomSpace(),
        ],
      ),
    );
  }
}
