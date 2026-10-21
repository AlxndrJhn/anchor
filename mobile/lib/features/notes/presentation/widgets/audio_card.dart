import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:just_audio/just_audio.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/play_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../data/repository/attachment_file_provider.dart';
import '../../data/repository/note_attachments_repository.dart';
import '../../domain/note_attachment.dart';
import '../../domain/note_dates.dart';
import 'attachment_tile.dart';
import 'audio_playback.dart';
import 'note_surface.dart';

class AudioCard extends ConsumerStatefulWidget {
  const AudioCard({
    super.key,
    required this.attachment,
    required this.appearance,
    required this.onDelete,
  });

  final NoteAttachment attachment;
  final NoteAppearance appearance;
  final VoidCallback? onDelete;

  @override
  ConsumerState<AudioCard> createState() => _AudioCardState();
}

class _AudioCardState extends ConsumerState<AudioCard> {
  final _player = AudioPlayer();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;
  String? _loaded;
  Duration _at = Duration.zero;
  Duration _length = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(
        _player.isPlayingStream.listen((isPlaying) {
          if (mounted) setState(() => _playing = isPlaying);
        }),
      )
      ..add(
        _player.positionStream.listen((position) {
          if (mounted) setState(() => _at = position);
        }),
      )
      ..add(
        _player.durationStream.listen((duration) {
          if (mounted && duration != null) setState(() => _length = duration);
        }),
      );
    final local = widget.attachment.localPath;
    if (local != null && File(local).existsSync()) {
      _prepare(local).ignore();
    } else {
      _prepareStored().ignore();
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _prepareStored() async {
    final file = await ref.read(
      attachmentFileProvider(attachmentFileKeyOf(widget.attachment)).future,
    );
    if (file != null && mounted) await _prepare(file);
  }

  Future<void> _prepare(String file) async {
    if (_loaded == file) return;
    await _player.setAudioSource(AudioSource.uri(Uri.file(file)));
    _loaded = file;
  }

  Future<void> _toggle() async {
    Haptics.selection();
    if (_playing) return _player.pause();
    setState(() {
      _loading = _loaded == null;
      _failed = false;
    });
    try {
      final file =
          _loaded ??
          await ref.read(
            attachmentFileProvider(
              attachmentFileKeyOf(widget.attachment),
            ).future,
          );
      if (file == null) {
        if (mounted) {
          AppSnackbar.show(
            context,
            widget.attachment.kind == AttachmentKind.voiceNote
                ? context.l10n.voiceOffline
                : context.l10n.audioFileOffline,
            kind: SnackbarKind.info,
          );
        }
        return;
      }
      await _prepare(file);
      unawaited(_player.play());
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _nameIn(AppLocalizations l10n) {
    final name = widget.attachment.originalFilename;
    if (widget.attachment.kind == AttachmentKind.voiceNote) {
      return l10n.voiceNote;
    }
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final appearance = widget.appearance;
    final l10n = context.l10n;
    final name = _nameIn(l10n);
    final progress = _length.inMilliseconds == 0
        ? 0.0
        : (_at.inMilliseconds / _length.inMilliseconds).clamp(0.0, 1.0);
    final attachment = widget.attachment;
    final nameStyle = AppTypography.secondary
        .withSize(13.5) // off-scale: a voice note's name
        .copyWith(
          height: 1.4,
          fontWeight: AnchorTokens.fontWeightMedium,
          color: colors.appText,
        );
    final lineStyle = AppTypography.codeSmall.tabular.copyWith(
      fontSize: 11.5, // off-scale: a voice note's time
      height: 1.4,
      color: _failed || attachment.isUploadFailed
          ? colors.statusLate
          : appearance.colors.muted,
    );
    final line = attachment.isUploadFailed
        ? l10n.attachmentUploadFailed
        : attachment.isPendingUpload
        ? l10n.attachmentUploading
        : _failed
        ? l10n.voiceLoadFailed
        : _length == Duration.zero
        ? ''
        : '${durationLabel(_at)} / ${durationLabel(_length)}';
    final tile = AttachmentTile(
      width: 210, // off-scale: a voice note's tile
      appearance: appearance,
      deleteLabel: l10n.commonDeleteItem(name),
      onDelete: widget.onDelete,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appearance.colors.surface,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
          border: Border.all(
            color: appearance.colors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              spacing: AnchorTokens.space10, // off-scale: a voice note's tile
              children: [
                PlayButton(
                  isPlaying: _playing,
                  isLoading: _loading,
                  name: name,
                  iconColor: appearance.colors.bg,
                  onPressed: _toggle,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          right: widget.onDelete == null ? 0 : 18,
                        ), // off-scale: room for the delete button
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                      ),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: lineStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (attachment.isUploadFailed)
              _RetryUpload(
                name: name,
                onRetry: () => ref
                    .read(noteAttachmentsRepositoryProvider)
                    .retryUpload(attachment.id),
              )
            else
              _SeekBar(
                progress: progress,
                appearance: appearance,
                label: l10n.voicePosition(name),
                onSeek: _length == Duration.zero
                    ? null
                    : (f) => _player.seek(_length * f),
              ),
          ],
        ),
      ),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _textScaleThatFits(nameStyle, lineStyle),
      child: tile,
    );
  }
}

double _textScaleThatFits(TextStyle name, TextStyle line) {
  double heightOf(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Hg', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  const room = AttachmentTile.height - 12 * 2 - _SeekBar.height;
  return room / (heightOf(name) + heightOf(line));
}

class _RetryUpload extends StatelessWidget {
  const _RetryUpload({required this.name, required this.onRetry});

  final String name;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Pressable(
        style: PressStyle.plain,
        onTap: onRetry,
        semanticLabel: context.l10n.attachmentRetry(name),
        child: SizedBox(
          height: _SeekBar.height,
          child: Center(
            widthFactor: 1,
            child: Text(
              context.l10n.commonTryAgain,
              style: AppTypography.footnote.copyWith(
                fontWeight: FontWeight.w600,
                color: context.anchor.appText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.progress,
    required this.appearance,
    required this.label,
    required this.onSeek,
  });

  static const double height = 24;

  final double progress;
  final NoteAppearance appearance;
  final String label;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return LayoutBuilder(
      builder: (context, box) {
        void seekAt(double x) =>
            onSeek?.call((x / box.maxWidth).clamp(0.0, 1.0));
        return Semantics(
          slider: true,
          label: label,
          value: NumberFormat.percentPattern(
            context.l10n.localeName,
          ).format(progress),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => seekAt(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
            child: SizedBox(
              height: height,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: appearance.colors.border,
                      borderRadius: BorderRadius.circular(
                        AnchorTokens.radiusPill,
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.appText,
                        borderRadius: BorderRadius.circular(
                          AnchorTokens.radiusPill,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (box.maxWidth - 12) * progress,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.appText,
                        shape: BoxShape.circle,
                        boxShadow: colors.shadowKnob,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
