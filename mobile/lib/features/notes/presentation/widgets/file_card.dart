import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/files/device_files.dart';
import '../../../../core/files/save_to_device.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_tags.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../data/repository/attachment_file_provider.dart';
import '../../data/repository/note_attachments_repository.dart';
import '../../domain/note_attachment.dart';
import 'attachment_tile.dart';
import 'file_icons.dart';
import 'note_surface.dart';

/// An attached file that isn't a picture or a recording: its name and size.
/// Tapping it opens it in an app that can; it can be saved too.
class FileCard extends ConsumerStatefulWidget {
  const FileCard({
    super.key,
    required this.attachment,
    required this.appearance,
    required this.onDelete,
  });

  final NoteAttachment attachment;
  final NoteAppearance appearance;
  final VoidCallback? onDelete;

  static const double width = 210; // off-scale: as wide as a voice note

  @override
  ConsumerState<FileCard> createState() => _FileCardState();
}

class _FileCardState extends ConsumerState<FileCard> {
  bool _isLoading = false;

  /// The file on the phone, fetched first when needed; null when it can't
  /// be, after saying why.
  Future<String?> _file() async {
    final attachment = widget.attachment;
    final local = attachment.localPath;
    if (local != null && File(local).existsSync()) return local;
    final l10n = context.l10n;
    setState(() => _isLoading = true);
    try {
      final file = await ref.read(
        attachmentFileProvider(attachmentFileKeyOf(attachment)).future,
      );
      if (file == null && mounted) {
        AppSnackbar.show(context, l10n.fileOffline, kind: SnackbarKind.info);
      }
      return file;
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.attachments,
        'Loading an attached file failed',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          l10n.fileLoadFailed,
          kind: SnackbarKind.error,
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _open() async {
    final attachment = widget.attachment;
    if (attachment.isUploadFailed) {
      Haptics.light();
      await ref
          .read(noteAttachmentsRepositoryProvider)
          .retryUpload(attachment.id);
      return;
    }
    Haptics.light();
    final l10n = context.l10n;
    final path = await _file();
    if (path == null || !mounted) return;
    var opened = false;
    try {
      opened = await openWithApp(
        path: path,
        name: attachment.originalFilename,
        mimeType: attachment.mimeType,
      );
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.attachments,
        'Opening an attached file failed: $error',
      );
    }
    if (!opened && mounted) {
      AppSnackbar.show(context, l10n.fileNoApp, kind: SnackbarKind.info);
    }
  }

  Future<void> _save() async {
    Haptics.light();
    final l10n = context.l10n;
    final attachment = widget.attachment;
    final path = await _file();
    if (path == null || !mounted) return;
    try {
      final saved = await saveFileToDevice(
        path: path,
        name: attachment.originalFilename,
        dialogTitle: l10n.fileSaveDialog,
        mimeType: attachment.mimeType,
      );
      if (saved && mounted) {
        AppSnackbar.show(context, l10n.fileSaved(attachment.originalFilename));
      }
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.attachments,
        'Saving an attached file failed',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          l10n.fileSaveFailed,
          kind: SnackbarKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final appearance = widget.appearance;
    final l10n = context.l10n;
    final attachment = widget.attachment;
    final name = attachment.originalFilename;
    final radius = context.appStyle.corners(AnchorTokens.radiusTile);
    final line = attachment.isUploadFailed
        ? l10n.attachmentUploadFailed
        : attachment.isPendingUpload
        ? l10n.attachmentUploading
        : fileSizeLabel(attachment.fileSize, l10n.localeName);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: AttachmentTile(
        width: FileCard.width,
        appearance: appearance,
        deleteLabel: l10n.commonDeleteItem(name),
        onDelete: widget.onDelete,
        // Open and Save side by side, so each keeps its own name for
        // screen readers.
        child: Stack(
          children: [
            Positioned.fill(
              child: Pressable(
                style: PressStyle.button,
                onTap: _isLoading ? null : _open,
                semanticLabel: attachment.isUploadFailed
                    ? l10n.attachmentRetry(name)
                    : l10n.fileOpen(name),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: appearance.colors.surface,
                    borderRadius: radius,
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: appearance.colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        height: AnchorTokens.sizeIconLarge,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _isLoading
                              ? SizedBox.square(
                                  dimension: AnchorTokens.sizeIconMedium,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: appearance.colors.muted,
                                  ),
                                )
                              : Icon(
                                  fileIconOf(attachment.mimeType, name),
                                  size: AnchorTokens.sizeIconMedium,
                                  color: appearance.colors.muted,
                                ),
                        ),
                      ),
                      Padding(
                        // Room for Save.
                        padding: const EdgeInsets.only(right: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.secondary
                                  .withSize(
                                    13.5,
                                  ) // off-scale: as a voice note's
                                  .copyWith(
                                    height: 1.4,
                                    fontWeight: AnchorTokens.fontWeightMedium,
                                    color: colors.appText,
                                  ),
                            ),
                            Text(
                              line,
                              maxLines: 1,
                              style: AppTypography.footnote.tabular.copyWith(
                                color: attachment.isUploadFailed
                                    ? colors.statusLate
                                    : appearance.colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Pressable(
                style: PressStyle.plain,
                onTap: _isLoading ? null : _save,
                semanticLabel: l10n.fileSave(name),
                child: SizedBox.square(
                  dimension: 32,
                  child: Icon(
                    LucideIcons.download,
                    size: AnchorTokens.sizeIconSmall,
                    color: appearance.colors.muted,
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
