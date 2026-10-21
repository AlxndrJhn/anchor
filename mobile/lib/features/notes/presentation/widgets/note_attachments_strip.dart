import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/animated_resize.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../data/repository/note_attachments_repository.dart';
import '../../domain/note_attachment.dart';
import '../note_labels.dart';
import '../note_morph_route.dart';
import 'attachment_tile.dart';
import 'audio_card.dart';
import 'note_surface.dart';
import 'picture_tile.dart';
import 'picture_viewer.dart';

class NoteAttachmentsStrip extends ConsumerStatefulWidget {
  const NoteAttachmentsStrip({
    super.key,
    required this.noteId,
    required this.appearance,
    required this.canEdit,
    required this.isOwner,
    required this.onAdd,
    this.currentUserId,
  });

  final String noteId;
  final NoteAppearance appearance;
  final bool canEdit;
  final bool isOwner;
  final String? currentUserId;
  final VoidCallback onAdd;

  @override
  ConsumerState<NoteAttachmentsStrip> createState() =>
      _NoteAttachmentsStripState();
}

class _NoteAttachmentsStripState extends ConsumerState<NoteAttachmentsStrip> {
  /// Attachments deleted while their Undo snackbar shows.
  final Set<String> _pendingRemovalIds = {};

  bool _loaded = false;
  String _shown = '';
  late final Stream<List<NoteAttachment>> _stream = ref
      .read(noteAttachmentsRepositoryProvider)
      .watchAttachments(widget.noteId);

  bool _canDelete(NoteAttachment attachment) {
    if (!widget.canEdit) return false;
    if (widget.isOwner ||
        attachment.isPendingUpload ||
        attachment.isUploadFailed) {
      return true;
    }
    return widget.currentUserId != null &&
        attachment.uploadedByUserId == widget.currentUserId;
  }

  bool _isPendingRemoval(NoteAttachment attachment) {
    final repo = ref.read(noteAttachmentsRepositoryProvider);
    return _pendingRemovalIds.any(
      (id) => repo.currentIdOf(id) == attachment.id,
    );
  }

  void _delete(NoteAttachment attachment) {
    Haptics.light();
    final repo = ref.read(noteAttachmentsRepositoryProvider);
    final noteId = widget.noteId;
    setState(() => _pendingRemovalIds.add(attachment.id));
    AppSnackbar.show(
      context,
      attachmentDeletedLabel(attachment.kind, context.l10n),
      actionLabel: context.l10n.commonUndo,
      onAction: () {
        if (mounted) setState(() => _pendingRemovalIds.remove(attachment.id));
      },
      onClosed: (undone) {
        if (!undone) unawaited(repo.deleteAttachment(noteId, attachment.id));
      },
    );
  }

  void _open(List<NoteAttachment> pictures, NoteAttachment picture) {
    Haptics.light();
    showPictureViewer(
      context,
      noteId: widget.noteId,
      pictures: pictures,
      initial: pictures.indexOf(picture),
      canDelete: _canDelete,
      onDelete: _delete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteAttachment>>(
      stream: _stream,
      builder: (context, snapshot) {
        final all = (snapshot.data ?? const <NoteAttachment>[])
            .where((attachment) => !_isPendingRemoval(attachment))
            .toList();
        final pictures = all.where((attachment) => attachment.isImage).toList();
        final audioFiles = all
            .where((attachment) => attachment.isAudio)
            .toList();
        final first = !_loaded && snapshot.hasData;
        if (snapshot.hasData) _loaded = true;
        final shown = all.map((attachment) => attachment.id).join(',');
        if (shown != _shown) {
          _shown = shown;
          NoteMorphRoute.refreshOf(context);
        }
        final tiles = <Widget>[
          for (final picture in pictures)
            PictureTile(
              key: ValueKey(picture.id),
              attachment: picture,
              appearance: widget.appearance,
              onOpen: () => _open(pictures, picture),
              onDelete: _canDelete(picture) ? () => _delete(picture) : null,
            ),
          for (final audio in audioFiles)
            AudioCard(
              key: ValueKey(audio.id),
              attachment: audio,
              appearance: widget.appearance,
              onDelete: _canDelete(audio) ? () => _delete(audio) : null,
            ),
          if (widget.canEdit && all.isNotEmpty)
            _AddTile(appearance: widget.appearance, onTap: widget.onAdd),
        ];
        return AnimatedResize(
          duration: first ? Duration.zero : Spring.smooth.duration,
          curve: Spring.smooth.curve,
          alignment: Alignment.topCenter,
          child: all.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: EdgeInsets.only(bottom: context.density.space16),
                  child: SizedBox(
                    height: AttachmentTile.height + 8,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: tiles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => tiles[i],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.appearance, required this.onTap});

  final NoteAppearance appearance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      style: PressStyle.button,
      onTap: onTap,
      semanticLabel: context.l10n.attachmentAddLabel,
      child: Container(
        width: AttachmentTile.height,
        height: AttachmentTile.height,
        decoration: BoxDecoration(
          color: appearance.colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
          border: Border.all(
            color: appearance.colors.border.withValues(alpha: 0.9),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: [
            Icon(
              LucideIcons.plus,
              size: AnchorTokens.sizeIconMedium,
              color: appearance.colors.muted,
            ),
            Text(
              context.l10n.attachmentAdd,
              style: AppTypography.footnote.copyWith(
                fontWeight: FontWeight.w600,
                color: appearance.colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
