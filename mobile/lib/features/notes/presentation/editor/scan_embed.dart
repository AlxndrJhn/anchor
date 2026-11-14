import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_tags.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/l10n.dart';
import '../../data/repository/note_attachments_repository.dart';
import '../../data/scan_pdf.dart';
import '../../domain/inline_image.dart';
import '../../domain/scan_document.dart';
import '../widgets/scan_document_screen.dart';

/// What the scans in a note's text need: their photos found or fetched, new
/// photos attached, and photos no page uses any more let go.
class Scans {
  Scans({required this.repo, required this.noteId, required this.attach});

  final NoteAttachmentsRepository repo;

  /// The note the scans belong to; null before it's saved.
  final String? Function() noteId;

  /// Attaches the JPEG at a path to the note (saving a new note first) and
  /// returns its id; null when it couldn't be, after saying why.
  final Future<String?> Function(String path) attach;

  Future<String?> findPhoto(String id) async {
    final attachment = await repo.watchAttachment(id).first;
    if (attachment == null) return null;
    final local = attachment.localPath;
    if (local != null && File(local).existsSync()) return local;
    try {
      final path = await repo.downloadAttachment(
        attachment.noteId,
        attachment.id,
        attachment.originalFilename,
      );
      return path.isEmpty ? null : path;
    } catch (e) {
      AppLogger.instance.warn(
        LogTags.attachments,
        'Fetching a scan photo failed: $e',
      );
      return null;
    }
  }

  /// [scan] with the photos taken for it on this phone attached; null when
  /// one couldn't be.
  Future<ScanDocument?> attachNew(ScanDocument scan) async {
    final pages = <ScanPage>[];
    for (final page in scan.pages) {
      if (!page.id.startsWith(localScanPhoto)) {
        pages.add(page);
        continue;
      }
      final path = page.id.substring(localScanPhoto.length);
      final id = await attach(path);
      if (id == null) return null;
      unawaited(File(path).delete().catchError((_) => File(path)));
      pages.add(page.copyWith(id: id));
    }
    return scan.copyWith(pages: pages);
  }

  /// Lets go of the photos among [ids] that nothing in [controller]'s text
  /// shows any more.
  Future<void> dropUnused(QuillController controller, Set<String> ids) async {
    final noteId = this.noteId();
    if (noteId == null || ids.isEmpty) return;
    final shown = <String>{};
    for (final op in controller.document.toDelta().toList()) {
      final data = op.data;
      if (data is! Map) continue;
      final scan = ScanDocument.tryParse(data[ScanDocument.embedType]);
      if (scan != null) shown.addAll(scan.pages.map((p) => p.id));
      final image = InlineImage.tryParse(data[InlineImage.embedType]);
      if (image != null) shown.add(image.id);
    }
    for (final id in ids.difference(shown)) {
      await repo.deleteAttachment(noteId, id);
    }
  }

  /// Makes [scan]'s PDF and opens the share sheet with it.
  Future<void> sharePdf(BuildContext context, ScanDocument scan) async {
    final l10n = context.l10n;
    final photos = <String, String>{};
    for (final page in scan.pages) {
      final path = await findPhoto(page.id);
      if (path == null) {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            l10n.scanPhotoMissing,
            kind: SnackbarKind.error,
          );
        }
        return;
      }
      photos[page.id] = path;
    }
    final File pdf;
    try {
      pdf = await makeScanPdf(scan, photos, fallbackName: l10n.scanTitle);
    } catch (e) {
      AppLogger.instance.warn(LogTags.attachments, 'Making a PDF failed: $e');
      if (context.mounted) {
        AppSnackbar.show(context, l10n.scanPdfFailed, kind: SnackbarKind.error);
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(pdf.path, mimeType: 'application/pdf')]),
    );
  }
}

/// Draws the scans in a note's text ([ScanDocument]); a tap opens one to
/// change it.
class ScanEmbedBuilder extends EmbedBuilder {
  const ScanEmbedBuilder(this.scans);

  final Scans scans;

  @override
  String get key => ScanDocument.embedType;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final scan = ScanDocument.tryParse(embedContext.node.value.data);
    if (scan == null) return const SizedBox.shrink();
    return _ScanEmbed(
      scan: scan,
      scans: scans,
      place: _Place(embedContext.controller, embedContext.node),
      readOnly: embedContext.readOnly,
    );
  }
}

class _ScanEmbed extends StatefulWidget {
  const _ScanEmbed({
    required this.scan,
    required this.scans,
    required this.place,
    required this.readOnly,
  });

  final ScanDocument scan;
  final Scans scans;
  final _Place place;
  final bool readOnly;

  @override
  State<_ScanEmbed> createState() => _ScanEmbedState();
}

class _ScanEmbedState extends State<_ScanEmbed> {
  final _photos = <String, Future<String?>>{};
  bool _isSharing = false;

  Future<String?> _photo(String id) =>
      _photos[id] ??= widget.scans.findPhoto(id);

  Future<void> _open() async {
    final before = widget.scan.pages.map((p) => p.id).toSet();
    final result = await ScanDocumentScreen.open(
      context,
      scan: widget.scan,
      findPhoto: widget.scans.findPhoto,
    );
    if (!mounted) return;
    switch (result) {
      case ScanSaved(:final scan):
        final attached = await widget.scans.attachNew(scan);
        if (attached == null || !mounted) return;
        widget.place.replace(attached);
        await widget.scans.dropUnused(widget.place.controller, before);
      case ScanRemoved():
        // The photos stay attached, as on the web, so undoing brings the
        // scan back whole.
        widget.place.remove();
      case null:
        break;
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;
    Haptics.light();
    setState(() => _isSharing = true);
    try {
      await widget.scans.sharePdf(context, widget.scan);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.anchor;
    final scan = widget.scan;
    final title = scan.title.isEmpty ? l10n.scanTitle : scan.title;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        container: true,
        button: !widget.readOnly,
        label: '$title, ${l10n.scanPages(scan.pages.length)}',
        hint: widget.readOnly ? null : l10n.scanOpenHint,
        child: Material(
          color: colors.appText.withValues(alpha: 0.04),
          borderRadius: context.appStyle.corners(AnchorTokens.radiusTile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.readOnly ? null : _open,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.scanLine,
                        size: AnchorTokens.sizeIconMedium,
                        color: colors.accentStrong,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '  ${l10n.scanPages(scan.pages.length)}',
                                  style: TextStyle(color: colors.appMuted),
                                ),
                              ],
                            ),
                            style: AppTypography.row,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      BarButton(
                        key: const ValueKey('scan-embed-share'),
                        icon: _isSharing
                            ? LucideIcons.loader
                            : LucideIcons.share,
                        label: l10n.scanSharePdf,
                        onPressed: scan.pages.isEmpty || _isSharing
                            ? null
                            : _share,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 128, // off-scale: a row of page thumbnails
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: scan.pages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => AspectRatio(
                        aspectRatio: 3 / 4,
                        child: ScanPageThumbnail(
                          photo: _photo(scan.pages[i].id),
                          page: scan.pages[i],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A scan's spot in the text, to change it there.
class _Place {
  const _Place(this.controller, this.node);

  final QuillController controller;
  final Embed node;

  /// Null once the scan has left the text.
  int? get offset {
    if (node.parent == null) return null;
    final at = node.documentOffset;
    final there = controller.document.querySegmentLeafNode(at).leaf;
    return identical(there, node) ? at : null;
  }

  void replace(ScanDocument scan) {
    final at = offset;
    if (at == null) return;
    _quietly(
      () => controller.replaceText(
        at,
        1,
        BlockEmbed(ScanDocument.embedType, scan.encode()),
        null,
      ),
    );
  }

  void remove() {
    final at = offset;
    if (at == null) return;
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

  void _quietly(VoidCallback change) {
    controller.skipRequestKeyboard = true;
    change();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.skipRequestKeyboard = false,
    );
  }
}
