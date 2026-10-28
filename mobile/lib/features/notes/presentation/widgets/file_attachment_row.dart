import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:anchor/core/files/device_files.dart';
import 'package:anchor/core/files/save_to_device.dart';
import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/theme/tokens/app_icon_sizes.dart';
import 'package:anchor/core/theme/tokens/app_radius.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/core/widgets/confirm_dialog.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart';

/// An attached file that isn't a picture or a recording: its name and
/// size. Tapping it opens it in an app that can; it can be saved too.
class FileAttachmentRow extends StatefulWidget {
  final NoteAttachment attachment;
  final bool canDelete;
  final bool isOnline;
  final VoidCallback? onDelete;

  /// Fetches the file when it isn't on the phone; returns its path.
  final Future<String> Function() onDownload;

  const FileAttachmentRow({
    super.key,
    required this.attachment,
    required this.onDownload,
    this.canDelete = false,
    this.isOnline = true,
    this.onDelete,
  });

  @override
  State<FileAttachmentRow> createState() => _FileAttachmentRowState();
}

class _FileAttachmentRowState extends State<FileAttachmentRow> {
  bool _isLoading = false;

  /// The file on the phone, fetched first when needed; null when it can't be.
  Future<String?> _file() async {
    final local = widget.attachment.localPath;
    if (local != null && File(local).existsSync()) return local;
    if (!widget.isOnline) {
      AppSnackbar.showInfo(context, message: 'Available when online');
      return null;
    }
    setState(() => _isLoading = true);
    try {
      return await widget.onDownload();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, message: 'Couldn’t load the file');
      }
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _open() async {
    HapticFeedback.lightImpact();
    final path = await _file();
    if (path == null || !mounted) return;
    final opened = await openWithApp(
      path: path,
      name: widget.attachment.originalFilename,
      mimeType: widget.attachment.mimeType,
    );
    if (!opened && mounted) {
      AppSnackbar.showInfo(
        context,
        message: 'No app on this phone opens it. Save it instead.',
      );
    }
  }

  Future<void> _save() async {
    final path = await _file();
    if (path == null || !mounted) return;
    await saveFileToDevice(
      context,
      sourcePath: path,
      filename: widget.attachment.originalFilename,
      tag: 'Attachments',
    );
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.mediumImpact();
    final confirm = await ConfirmDialog.show(
      context: context,
      icon: LucideIcons.trash2,
      iconColor: Theme.of(context).colorScheme.error,
      title: 'Delete file?',
      message:
          'This will permanently delete "${widget.attachment.originalFilename}".',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirm == true) widget.onDelete?.call();
  }

  IconData get _icon {
    final mime = widget.attachment.mimeType;
    final name = widget.attachment.originalFilename.toLowerCase();
    if (mime == 'application/zip' || name.endsWith('.zip')) {
      return LucideIcons.fileArchive;
    }
    if (mime.startsWith('text/') ||
        mime == 'application/pdf' ||
        mime.contains('document')) {
      return LucideIcons.fileText;
    }
    if (mime.startsWith('image/')) return LucideIcons.fileImage;
    if (mime.startsWith('video/')) return LucideIcons.fileVideo;
    return LucideIcons.file;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: _isLoading ? null : _open,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dims.md, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: AppRadius.lgBorder,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.buttonBorder,
              ),
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : Icon(
                      _icon,
                      size: AppIconSizes.lg,
                      color: theme.colorScheme.primary,
                    ),
            ),
            SizedBox(width: dims.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.attachment.originalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: dims.xxs),
                  Text(
                    widget.attachment.isPendingUpload
                        ? '${fileSizeLabel(widget.attachment.fileSize)} · Pending'
                        : fileSizeLabel(widget.attachment.fileSize),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: dims.xs),
            IconButton(
              onPressed: _isLoading ? null : _save,
              icon: Icon(LucideIcons.download, size: 18, color: muted),
              tooltip: 'Download file',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(shape: const CircleBorder()),
            ),
            if (widget.canDelete) ...[
              SizedBox(width: dims.xs),
              IconButton(
                onPressed: _confirmDelete,
                icon: Icon(LucideIcons.trash2, size: 18, color: muted),
                tooltip: 'Delete file',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(shape: const CircleBorder()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// “820 KB”, “3.4 MB”.
String fileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
