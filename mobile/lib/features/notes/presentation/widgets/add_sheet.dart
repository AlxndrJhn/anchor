import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/files/device_files.dart';
import '../../../../core/motion/animated_resize.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_sheet.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/grouped_list.dart';
import '../../../../core/widgets/play_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../data/photo_files.dart';
import '../../domain/note_attachment.dart';
import '../../domain/note_dates.dart';
import 'audio_playback.dart';

typedef AddedFile = ({String path, String mime, String name});

/// What was picked, recorded or taken, once the sheet has closed; null when
/// nothing was. Take several closes the sheet and calls [onTakeSeveral]
/// (null leaves it out).
Future<List<AddedFile>?> showAddSheet(
  BuildContext context, {
  VoidCallback? onTakeSeveral,
}) {
  return showAnchorSheet<List<AddedFile>>(
    context,
    semanticLabel: context.l10n.addToNote,
    builder: (_) => _AddSheet(onTakeSeveral: onTakeSeveral),
  );
}

/// [images] as files the server takes: photos it can't show (HEIC and the
/// like) are made JPEG first; [unsupported] counts the ones that couldn't be.
Future<({List<AddedFile> files, int unsupported})> uploadablePictures(
  List<XFile> images,
) async {
  final files = <AddedFile>[];
  var unsupported = 0;
  for (final image in images) {
    final photo = await PhotoFiles.uploadable(image.path);
    if (photo == null) {
      unsupported++;
    } else {
      files.add((
        path: photo.path,
        mime: photo.mime,
        name: path.basename(photo.path),
      ));
    }
  }
  return (files: files, unsupported: unsupported);
}

enum _Stage { pick, recording, review }

const _waveformBarCount = 36;

const _recordingLimit = maxAttachmentBytes - 2 * 1024 * 1024;

class _AddSheet extends StatefulWidget {
  const _AddSheet({this.onTakeSeveral});

  final VoidCallback? onTakeSeveral;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  _Stage _stage = _Stage.pick;
  StreamSubscription<Amplitude>? _levels;
  StreamSubscription<Duration>? _position;
  StreamSubscription<bool>? _playing;
  Timer? _clock;
  DateTime _startedAt = DateTime.now();
  Duration _length = Duration.zero;
  Duration _played = Duration.zero;
  bool _isPlaying = false;
  bool _isStoppedAtLimit = false;
  String? _file;

  /// Levels from 0 to 1, newest last.
  final List<double> _amplitudes = [];

  @override
  void dispose() {
    _clock?.cancel();
    _levels?.cancel();
    _position?.cancel();
    _playing?.cancel();
    final unattached = _file;
    final stopped = _stage == _Stage.recording
        ? _recorder.stop()
        : Future<void>.value();
    if (unattached != null) {
      stopped.whenComplete(() => File(unattached).delete()).ignore();
    }
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _done(List<AddedFile> files) =>
      Navigator.of(context).pop<List<AddedFile>>(files);

  Future<List<AddedFile>?> _uploadable(List<XFile> images) async {
    final pictures = await uploadablePictures(images);
    if (!mounted) return null;
    if (pictures.unsupported > 0) {
      AppSnackbar.show(
        context,
        context.l10n.addPhotoUnsupported,
        kind: SnackbarKind.error,
      );
    }
    return pictures.files;
  }

  Future<void> _takePhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image == null || !mounted) return;
    final files = await _uploadable([image]);
    if (files != null && files.isNotEmpty) _done(files);
  }

  void _takeSeveral() {
    final onTakeSeveral = widget.onTakeSeveral!;
    Navigator.of(context).pop();
    onTakeSeveral();
  }

  /// Several photos from the gallery at once.
  Future<void> _choosePhotos() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isEmpty || !mounted) return;
    final files = await _uploadable(images);
    if (files != null && files.isNotEmpty) _done(files);
  }

  /// Any kind of file, several at once.
  Future<void> _chooseFiles() async {
    final picked = await FilePicker.pickFiles();
    final files = [
      for (final file in picked)
        if (file.path case final filePath?)
          (
            path: filePath,
            mime: mimeTypeFor(file.name),
            name: file.name.isEmpty ? path.basename(filePath) : file.name,
          ),
    ];
    if (files.isEmpty || !mounted) return;
    _done(files);
  }

  /// A whole folder, subfolders included, as one zip file.
  Future<void> _chooseFolder() async {
    final ZippedFolder? folder;
    try {
      folder = await pickFolderAsZip();
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          context.l10n.addFolderFailed,
          kind: SnackbarKind.error,
        );
      }
      return;
    }
    if (folder == null || !mounted) return;
    if (folder.fileCount == 0) {
      AppSnackbar.show(context, context.l10n.addFolderEmpty);
      try {
        await File(folder.path).delete();
      } catch (_) {}
      return;
    }
    _done([(path: folder.path, mime: 'application/zip', name: folder.name)]);
  }

  Future<void> _record() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        AppSnackbar.show(
          context,
          context.l10n.addMicDenied,
          kind: SnackbarKind.error,
        );
      }
      return;
    }
    await _discardRecording();
    _isStoppedAtLimit = false;
    final dir = await getTemporaryDirectory();
    final file = path.join(
      dir.path,
      '$recordingFilePrefix${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 96000,
        sampleRate: 44100,
        numChannels: 1,
        echoCancel: true,
        autoGain: true,
        noiseSuppress: true,
      ),
      path: file,
    );
    if (!mounted) return;
    Haptics.medium();
    _amplitudes.clear();
    _startedAt = DateTime.now();
    _levels = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen((amplitude) {
          // -50 dB and under reads as silence; 0 dB fills the bar.
          final level = ((amplitude.current + 50) / 50).clamp(0.0, 1.0);
          if (mounted) {
            setState(() => _amplitudes.add(0.12 + 0.88 * math.pow(level, 1.4)));
          }
        });
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) {
        setState(() => _length = DateTime.now().difference(_startedAt));
      }
      if (!_isStoppedAtLimit && File(file).statSync().size >= _recordingLimit) {
        _isStoppedAtLimit = true;
        unawaited(_stop());
      }
    });
    setState(() {
      _stage = _Stage.recording;
      _file = file;
      _length = Duration.zero;
    });
  }

  Future<void> _stop() async {
    _clock?.cancel();
    await _levels?.cancel();
    final file = await _recorder.stop();
    if (!mounted) return;
    if (file == null) {
      setState(() => _stage = _Stage.pick);
      return;
    }
    Haptics.light();
    try {
      final length = await _player.setFilePath(file);
      _position = _player.positionStream.listen((position) {
        if (mounted) setState(() => _played = position);
      });
      _playing = _player.isPlayingStream.listen((isPlaying) {
        if (mounted) setState(() => _isPlaying = isPlaying);
      });
      setState(() {
        _stage = _Stage.review;
        _file = file;
        _length = length ?? _length;
        _played = Duration.zero;
      });
    } catch (_) {
      _attachRecording();
    }
  }

  Future<void> _discardRecording() async {
    await _player.stop();
    await _position?.cancel();
    await _playing?.cancel();
    final file = _file;
    _file = null;
    if (file != null) {
      try {
        await File(file).delete();
      } catch (_) {}
    }
  }

  void _attachRecording() {
    final file = _file;
    if (file == null) return;
    _file = null;
    unawaited(_player.stop());
    _done([(path: file, mime: 'audio/mp4', name: path.basename(file))]);
  }

  Future<void> _discard() async {
    await _discardRecording();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelRecording() async {
    _clock?.cancel();
    await _levels?.cancel();
    await _recorder.stop();
    await _discardRecording();
    if (mounted) Navigator.of(context).pop();
  }

  List<double> _shownBars() {
    if (_amplitudes.isEmpty) return List.filled(_waveformBarCount, 0.12);
    if (_stage == _Stage.recording) {
      final tail = _amplitudes.length > _waveformBarCount
          ? _amplitudes.sublist(_amplitudes.length - _waveformBarCount)
          : _amplitudes;
      return [...List.filled(_waveformBarCount - tail.length, 0.12), ...tail];
    }
    return [
      for (var i = 0; i < _waveformBarCount; i++)
        _amplitudes
            .sublist(
              (i * _amplitudes.length / _waveformBarCount).floor(),
              math.max(
                (i * _amplitudes.length / _waveformBarCount).floor() + 1,
                ((i + 1) * _amplitudes.length / _waveformBarCount).floor(),
              ),
            )
            .reduce(math.max),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final seconds = math.max(1, _length.inSeconds);
    final l10n = context.l10n;
    // Android's folder screen zips a folder (DeviceFilesPlugin).
    final canPickFolder = defaultTargetPlatform == TargetPlatform.android;
    final (title, subtitle) = switch (_stage) {
      _Stage.pick => (l10n.addToNote, null),
      _Stage.recording => (l10n.recordingTitle, l10n.recordingHelp),
      _Stage.review => (
        l10n.recordingReviewTitle,
        _isStoppedAtLimit
            ? l10n.recordingStoppedAtLimit
            : l10n.recordingReviewHelp(seconds),
      ),
    };
    return PopScope(
      canPop: _stage != _Stage.recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelRecording();
      },
      child: AnimatedResize(
        duration: Spring.smooth.duration,
        curve: Spring.smooth.curve,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: title, subtitle: subtitle),
            if (_stage == _Stage.pick) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _OptionGrid(
                  options: [
                    _Option(
                      icon: LucideIcons.camera,
                      label: l10n.addTakePhoto,
                      onTap: _takePhoto,
                    ),
                    if (widget.onTakeSeveral != null)
                      _Option(
                        icon: LucideIcons.aperture,
                        label: l10n.addTakeSeveral,
                        onTap: _takeSeveral,
                      ),
                    _Option(
                      icon: LucideIcons.images,
                      label: l10n.addChoosePhoto,
                      onTap: _choosePhotos,
                    ),
                    _Option(
                      icon: LucideIcons.mic,
                      label: l10n.addRecordAudio,
                      onTap: _record,
                    ),
                    _Option(
                      icon: LucideIcons.file,
                      label: l10n.addFiles,
                      onTap: _chooseFiles,
                    ),
                    if (canPickFolder)
                      _Option(
                        icon: LucideIcons.folderArchive,
                        label: l10n.addFolder,
                        onTap: _chooseFolder,
                      ),
                  ],
                ),
              ),
              const SheetBottomSpace(),
            ] else ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16, context.density.space8, 16, 0),
                child: Column(
                  spacing: context.density.space16,
                  children: [
                    _Waveform(
                      bars: _shownBars(),
                      isRecording: _stage == _Stage.recording,
                      progress:
                          _stage == _Stage.review && _length.inMilliseconds > 0
                          ? _played.inMilliseconds / _length.inMilliseconds
                          : null,
                    ),
                    if (_stage == _Stage.recording)
                      Semantics(
                        liveRegion: false,
                        label: l10n.recordingElapsed(durationLabel(_length)),
                        child: ExcludeSemantics(
                          child: Text(
                            durationLabel(_length),
                            style: AppTypography.sheetTitle.tabular
                                .withSize(AppTypography.largeTitle.fontSize!)
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.anchor.appText,
                                ),
                          ),
                        ),
                      )
                    else
                      _PlayRow(
                        playing: _isPlaying,
                        text:
                            '${durationLabel(_played)} / ${durationLabel(_length)}',
                        onTap: () async {
                          Haptics.selection();
                          if (_isPlaying) {
                            await _player.pause();
                          } else {
                            await _player.play();
                          }
                        },
                      ),
                  ],
                ),
              ),
              if (_stage == _Stage.recording)
                SheetFooter(
                  children: [
                    AppButton(
                      label: l10n.commonCancel,
                      kind: AppButtonKind.secondary,
                      onPressed: _cancelRecording,
                    ),
                    AppButton(
                      label: l10n.recordingStop,
                      icon: LucideIcons.square,
                      kind: AppButtonKind.danger,
                      onPressed: _stop,
                    ),
                  ],
                )
              else
                SheetFooter(
                  children: [
                    AppButton(
                      label: l10n.recordingDiscard,
                      kind: AppButtonKind.dangerText,
                      onPressed: _discard,
                    ),
                    AppButton(
                      label: l10n.recordingAgain,
                      icon: LucideIcons.rotateCcw,
                      kind: AppButtonKind.secondary,
                      onPressed: _record,
                    ),
                    AppButton(
                      label: l10n.commonSave,
                      onPressed: () {
                        Haptics.success();
                        _attachRecording();
                      },
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Options two to a row; an odd one out keeps a half-width.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.options});

  final List<Widget> options;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 12,
    children: [
      for (var i = 0; i < options.length; i += 2)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Expanded(child: options[i]),
              Expanded(
                child: i + 1 < options.length
                    ? options[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final density = context.density;
    return Pressable(
      style: PressStyle.button,
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: BoxConstraints(minHeight: density.control * 2),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: density.space16,
        ),
        decoration: BoxDecoration(
          color: GroupedList.fillOf(context),
          borderRadius: context.appStyle.corners(AnchorTokens.radius2xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: density.space12,
          children: [
            Container(
              width: 40, // off-scale: the option's round icon
              height: 40, // off-scale: as above
              decoration: BoxDecoration(
                color: colors.accentStrong.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AnchorTokens.sizeIconMedium,
                color: colors.accentStrong,
              ),
            ),
            Text(
              label,
              style: AppTypography.row.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.appText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.bars,
    required this.isRecording,
    this.progress,
  });

  final List<double> bars;
  final bool isRecording;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final idleBarColor = colors.appMuted.withValues(alpha: 0.45);
    return ExcludeSemantics(
      child: SizedBox(
        height: 64, // off-scale: the waveform, a drawing
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 3, // off-scale: as above
          children: [
            for (var i = 0; i < bars.length; i++)
              AnimatedContainer(
                duration: context.motion(AnchorTokens.motionDurationPress),
                curve: AnchorTokens.motionEaseStandard,
                width: 4,
                height: 64 * bars[i], // off-scale: as above
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
                  color: isRecording
                      ? (bars[i] > 0.13 ? colors.statusDanger : idleBarColor)
                      : progress != null && i / bars.length < progress!
                      ? colors.accentStrong
                      : idleBarColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayRow extends StatelessWidget {
  const _PlayRow({
    required this.playing,
    required this.text,
    required this.onTap,
  });

  final bool playing;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 12,
      children: [
        PlayButton(
          isPlaying: playing,
          size: PlayButtonSize.large,
          onPressed: onTap,
        ),
        Text(
          text,
          style: AppTypography.secondary.tabular.copyWith(
            color: colors.appMuted,
          ),
        ),
      ],
    );
  }
}
