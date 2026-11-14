import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/l10n.dart';
import '../../note_locks/presentation/note_lock_session.dart';
import '../data/repository/note_attachments_repository.dart';
import '../domain/note.dart';
import '../domain/note_attachment.dart';
import '../domain/note_print_html.dart';

/// A note to print: [content] is what is on screen, which may not be saved
/// yet; null takes the note's own. [note] is null for a new note not saved
/// yet, which has no pictures.
typedef PrintRequest = ({Note? note, String title, String? content});

/// Hands [requests] to the system's print dialog, as one document, the same
/// way the web app prints: titles, text and pictures, on white. Locked
/// notes not opened this session print their title only.
Future<void> printNotes(
  BuildContext context,
  WidgetRef ref,
  List<PrintRequest> requests,
) async {
  if (requests.isEmpty) return;
  final l10n = context.l10n;
  final unlocked = ref.read(noteLockSessionProvider);
  final attachments = ref.read(noteAttachmentsRepositoryProvider);
  try {
    final notes = [
      for (final (:note, :title, :content) in requests)
        if (note != null && isNoteHidden(note, unlocked))
          PrintableNote(title: title, content: null, isLocked: true)
        else
          PrintableNote(
            title: title,
            content: content ?? note?.content,
            pictures: note == null
                ? const []
                : await _picturesOf(note.id, attachments),
          ),
    ];
    final html = notesToPrintHtml(
      notes,
      css: await rootBundle.loadString('assets/print/notes.css'),
      highlights: {
        for (final MapEntry(:key, :value)
            in AnchorColors.light.highlights.entries)
          key: _hex(value.fill),
      },
      lockedText: l10n.notePrintLocked,
    );
    final title = requests.length == 1 ? requests.single.title.trim() : '';
    await Printing.layoutPdf(
      name: title.isEmpty ? 'Anchor' : title,
      // Deprecated, but still kept up (5.15.1 fixed it on iOS 26). The
      // system's web view lays the note out as the web app's print does,
      // with every script and right-to-left line, which a PDF drawn here
      // would need fonts for.
      // ignore: deprecated_member_use
      onLayout: (format) => Printing.convertHtml(format: format, html: html),
    );
  } catch (e) {
    AppLogger.instance.warn(LogTags.notes, 'Print failed: $e');
    if (context.mounted) AppSnackbar.show(context, l10n.notePrintFailed);
  }
}

/// The note's pictures as `data:` URIs; ones that can't be had (offline and
/// never downloaded) are left out.
Future<List<String>> _picturesOf(
  String noteId,
  NoteAttachmentsRepository attachments,
) async {
  final all = await attachments.watchAttachments(noteId).first;
  final out = <String>[];
  for (final picture in all.where((a) => a.type == AttachmentType.image)) {
    try {
      final local = picture.localPath;
      final path = local != null && File(local).existsSync()
          ? local
          : await attachments.downloadAttachment(
              noteId,
              picture.id,
              picture.originalFilename,
            );
      final bytes = await File(path).readAsBytes();
      out.add('data:${picture.mimeType};base64,${base64Encode(bytes)}');
    } catch (e) {
      AppLogger.instance.debug(
        LogTags.attachments,
        'Print left out picture ${picture.id} (noteId=$noteId): $e',
      );
    }
  }
  return out;
}

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
