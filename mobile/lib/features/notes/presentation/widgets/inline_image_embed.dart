import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

import '../../../../core/files/picture_actions.dart';
import '../../../../core/files/picture_edits.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/app_icon_sizes.dart';
import '../../../../core/theme/tokens/app_radius.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/image_shimmer.dart';
import '../../data/repository/note_attachments_repository.dart';
import '../../domain/inline_image.dart';
import '../../domain/note_attachment.dart';
import 'image_crop_screen.dart';

/// Draws the pictures placed in a note's text ([InlineImage]).
class InlineImageEmbedBuilder extends EmbedBuilder {
  final InlineImages images;

  const InlineImageEmbedBuilder(this.images);

  @override
  String get key => InlineImage.embedType;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final image = InlineImage.tryParse(embedContext.node.value.data);
    if (image == null) return const SizedBox.shrink();
    return _InlineImageView(
      image: image,
      place: _Place(embedContext.controller, embedContext.node),
      readOnly: embedContext.readOnly,
      images: images,
    );
  }
}

/// A picture's spot in the text, to change it there.
class _Place {
  final QuillController controller;
  final Embed node;

  const _Place(this.controller, this.node);

  /// Null once the picture has left the text (deleted, undone, or the
  /// note reloaded).
  int? get offset {
    if (node.parent == null) return null;
    final at = node.documentOffset;
    final there = controller.document.querySegmentLeafNode(at).leaf;
    return identical(there, node) ? at : null;
  }

  void replace(InlineImage image) {
    final at = offset;
    if (at == null) return;
    _quietly(
      () => controller.replaceText(
        at,
        1,
        BlockEmbed(InlineImage.embedType, image.encode()),
        null,
      ),
    );
  }

  void remove() {
    final at = offset;
    if (at == null) return;
    // The picture's line goes with it.
    final hasLine =
        at + 1 < controller.document.length &&
        controller.document.getPlainText(at + 1, 1) == '\n';
    _quietly(
      () => controller.replaceText(
        at,
        hasLine ? 2 : 1,
        '',
        TextSelection.collapsed(offset: at),
      ),
    );
  }

  /// Changes the text without the keyboard popping up. (Ignoring focus
  /// instead would also keep the editor from redrawing the picture.)
  void _quietly(VoidCallback change) {
    controller.skipRequestKeyboard = true;
    change();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.skipRequestKeyboard = false,
    );
  }
}

/// What the pictures in a note's text do: load their attachment, and the
/// changes on their long-press menu.
class InlineImages {
  final NoteAttachmentsRepository repo;

  /// The note the pictures belong to; null before it's saved.
  final String? Function() noteId;

  InlineImages({required this.repo, required this.noteId});

  /// Whether the note is being edited: the resize handles show then.
  final editing = ValueNotifier(false);

  Stream<NoteAttachment?> watch(String id) => repo.watchAttachment(id);

  final _downloading = <String>{};

  /// Fetches a picture that isn't on the phone yet; the stream then has it.
  void download(NoteAttachment attachment) {
    if (!_downloading.add(attachment.id)) return;
    repo
        .downloadAttachment(
          attachment.noteId,
          attachment.id,
          attachment.originalFilename,
        )
        .catchError((Object e) {
          AppLogger.instance.warn('InlineImage', 'Download failed: $e');
          return '';
        })
        .whenComplete(() => _downloading.remove(attachment.id));
  }

  Future<void> _showMenu(
    BuildContext context,
    _Place place,
    InlineImage image,
    String? path,
  ) async {
    HapticFeedback.mediumImpact();
    final action = await AppBottomSheet.show<_Action>(
      context,
      builder: (context) => _InlineImageMenu(
        hasCaption: image.caption != null,
        canEdit: path != null,
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _Action.delete:
        place.remove();
        await _dropIfUnused(place, image.id);
      case _Action.retake:
        final shot = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 92,
        );
        if (shot == null || !context.mounted) return;
        await _swap(context, place, image, shot.path);
      case _Action.crop:
        final area = await ImageCropScreen.open(context, path!);
        if (area == null || !context.mounted) return;
        await _edit(context, place, image, path, CropTo(area));
      case _Action.mirrorHorizontally:
        await _edit(context, place, image, path!, const MirrorHorizontally());
      case _Action.mirrorVertically:
        await _edit(context, place, image, path!, const MirrorVertically());
      case _Action.caption:
        final caption = await _askCaption(context, image.caption);
        if (caption == null) return;
        place.replace(
          image.copyWith(
            caption: () => caption.trim().isEmpty ? null : caption.trim(),
          ),
        );
    }
  }

  Future<void> _edit(
    BuildContext context,
    _Place place,
    InlineImage image,
    String path,
    PictureEdit edit,
  ) async {
    final String edited;
    try {
      edited = await _whileBusy(context, editPicture(path, edit));
    } catch (e) {
      AppLogger.instance.warn('InlineImage', 'Editing the picture failed: $e');
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Couldn’t change the picture');
      }
      return;
    }
    if (!context.mounted) return;
    await _swap(context, place, image, edited);
    try {
      await File(edited).delete();
    } catch (_) {}
  }

  /// The picture at [place] becomes the one at [path], kept as a new
  /// attachment; the old one goes unless the text shows it elsewhere.
  Future<void> _swap(
    BuildContext context,
    _Place place,
    InlineImage image,
    String path,
  ) async {
    final noteId = this.noteId();
    if (noteId == null) return;
    try {
      final ext = p.extension(path).toLowerCase();
      final id = await repo.addAttachment(
        noteId,
        path,
        ext == '.png' ? 'image/png' : 'image/jpeg',
        'Picture ${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      place.replace(image.copyWith(id: id));
      await _dropIfUnused(place, image.id);
    } catch (e) {
      AppLogger.instance.warn(
        'InlineImage',
        'Replacing the picture failed: $e',
      );
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Couldn’t change the picture');
      }
    }
  }

  Future<void> _dropIfUnused(_Place place, String id) async {
    final noteId = this.noteId();
    if (noteId == null) return;
    final stillShown = place.controller.document.toDelta().toList().any(
      (op) =>
          op.data is Map &&
          InlineImage.tryParse((op.data as Map)[InlineImage.embedType])?.id ==
              id,
    );
    if (!stillShown) await repo.deleteAttachment(noteId, id);
  }

  void _view(BuildContext context, String path, String? caption) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: caption == null ? null : Text(caption),
            actions: [
              IconButton(
                tooltip: 'Share',
                onPressed: () =>
                    sharePicture(path: path, name: p.basename(path)),
                icon: const Icon(LucideIcons.share2),
              ),
              IconButton(
                tooltip: 'Copy picture',
                onPressed: () =>
                    copyPicture(context, path: path, name: p.basename(path)),
                icon: const Icon(LucideIcons.copy),
              ),
            ],
          ),
          body: PhotoView(
            imageProvider: FileImage(File(path)),
            minScale: PhotoViewComputedScale.contained,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

/// Runs [work] behind a spinner the user can't dismiss.
Future<T> _whileBusy<T>(BuildContext context, Future<T> work) async {
  final navigator = Navigator.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
  try {
    return await work;
  } finally {
    navigator.pop();
  }
}

Future<String?> _askCaption(BuildContext context, String? current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _CaptionDialog(current: current),
    );

/// Asks for a picture's caption; returns '' to remove it, null to cancel.
class _CaptionDialog extends StatefulWidget {
  final String? current;

  const _CaptionDialog({required this.current});

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  // Disposed with the dialog, once it has finished closing.
  late final _text = TextEditingController(text: widget.current ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    return AlertDialog(
      title: Text(current == null ? 'Add caption' : 'Edit caption'),
      content: TextField(
        controller: _text,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Caption'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _InlineImageView extends StatefulWidget {
  final InlineImage image;
  final _Place place;
  final bool readOnly;
  final InlineImages images;

  const _InlineImageView({
    required this.image,
    required this.place,
    required this.readOnly,
    required this.images,
  });

  @override
  State<_InlineImageView> createState() => _InlineImageViewState();
}

class _InlineImageViewState extends State<_InlineImageView> {
  late Stream<NoteAttachment?> _attachment;

  /// The width being dragged to, as a share of the text's; null when not.
  double? _resizing;

  @override
  void initState() {
    super.initState();
    _attachment = widget.images.watch(widget.image.id);
  }

  @override
  void didUpdateWidget(covariant _InlineImageView old) {
    super.didUpdateWidget(old);
    if (old.image.id != widget.image.id) {
      _attachment = widget.images.watch(widget.image.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dims.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final full = constraints.maxWidth;
          final share = (_resizing ?? widget.image.width ?? 1.0).clamp(
            InlineImage.minWidth,
            1.0,
          );
          return StreamBuilder<NoteAttachment?>(
            stream: _attachment,
            builder: (context, snapshot) {
              final attachment = snapshot.data;
              final path = attachment?.localPath;
              final hasFile = path != null && File(path).existsSync();
              if (attachment != null && !hasFile) {
                widget.images.download(attachment);
              }
              final picture = SizedBox(
                width: full * share,
                child: _picture(
                  context,
                  isGone:
                      snapshot.connectionState != ConnectionState.waiting &&
                      attachment == null,
                  path: hasFile ? path : null,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: hasFile
                        ? () => widget.images._view(
                            context,
                            path,
                            widget.image.caption,
                          )
                        : null,
                    onLongPress: widget.readOnly
                        ? null
                        : () => widget.images._showMenu(
                            context,
                            widget.place,
                            widget.image,
                            hasFile ? path : null,
                          ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        picture,
                        if (!widget.readOnly)
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: _ShownWhile(
                              editing: widget.images.editing,
                              child: _ResizeHandle(
                                onDrag: (dx) => setState(
                                  () => _resizing =
                                      ((_resizing ?? share) + dx / full).clamp(
                                        InlineImage.minWidth,
                                        1.0,
                                      ),
                                ),
                                onEnd: () {
                                  final width = _resizing;
                                  setState(() => _resizing = null);
                                  if (width == null) return;
                                  widget.place.replace(
                                    widget.image.copyWith(
                                      width: () => width >= 0.99 ? null : width,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.image.caption != null)
                    SizedBox(
                      width: full * share,
                      child: Padding(
                        padding: EdgeInsets.only(top: dims.xs),
                        child: Text(
                          widget.image.caption!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _picture(
    BuildContext context, {
    required bool isGone,
    required String? path,
  }) {
    final theme = Theme.of(context);
    if (path == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: AppRadius.mdBorder,
          child: isGone
              ? ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      LucideIcons.imageOff,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : const ImageShimmer(),
        ),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.mdBorder,
      child: Image.file(
        File(path),
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        // Room for the picture while it's read, so the text doesn't jump
        // and it can already be held.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null && !wasSynchronouslyLoaded
            ? AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [const ImageShimmer(), child],
                ),
              )
            : child,
        cacheWidth:
            (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
        errorBuilder: (context, _, _) => AspectRatio(
          aspectRatio: 4 / 3,
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              LucideIcons.imageOff,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] while the note is being edited; nothing otherwise.
class _ShownWhile extends StatelessWidget {
  final ValueListenable<bool> editing;
  final Widget child;

  const _ShownWhile({required this.editing, required this.child});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: editing,
    builder: (context, isEditing, child) => AnimatedOpacity(
      opacity: isEditing ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: IgnorePointer(ignoring: !isEditing, child: child),
    ),
    child: child,
  );
}

/// The round grip in a picture's corner that changes its width.
class _ResizeHandle extends StatelessWidget {
  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;

  const _ResizeHandle({required this.onDrag, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Resize picture',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        onHorizontalDragCancel: onEnd,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Icon(
              LucideIcons.moveDiagonal2,
              size: AppIconSizes.xs,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

enum _Action {
  retake,
  crop,
  mirrorHorizontally,
  mirrorVertically,
  caption,
  delete,
}

class _InlineImageMenu extends StatelessWidget {
  final bool hasCaption;

  /// Crop and mirror need the picture on the phone.
  final bool canEdit;

  const _InlineImageMenu({required this.hasCaption, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    Widget item(_Action action, IconData icon, String label, {Color? color}) =>
        ListTile(
          leading: Icon(icon, color: color ?? theme.colorScheme.onSurface),
          title: Text(label, style: TextStyle(color: color)),
          onTap: () => Navigator.of(context).pop(action),
        );
    return AppBottomSheet(
      icon: LucideIcons.image,
      title: 'Picture',
      contentPadding: EdgeInsets.fromLTRB(dims.sm, 0, dims.sm, dims.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(_Action.retake, LucideIcons.camera, 'Retake'),
          if (canEdit) ...[
            item(_Action.crop, LucideIcons.crop, 'Crop'),
            item(
              _Action.mirrorHorizontally,
              LucideIcons.flipHorizontal2,
              'Mirror horizontally',
            ),
            item(
              _Action.mirrorVertically,
              LucideIcons.flipVertical2,
              'Mirror vertically',
            ),
          ],
          item(
            _Action.caption,
            LucideIcons.captions,
            hasCaption ? 'Edit caption' : 'Add caption',
          ),
          item(
            _Action.delete,
            LucideIcons.trash2,
            'Delete',
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }
}
