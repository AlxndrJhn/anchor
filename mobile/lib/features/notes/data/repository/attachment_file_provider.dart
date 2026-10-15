import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/connectivity_provider.dart';
import '../../domain/note.dart';
import '../../domain/note_attachment.dart';
import 'note_attachments_repository.dart';

part 'attachment_file_provider.g.dart';

typedef AttachmentFileKey = ({
  String noteId,
  String attachmentId,
  String filename,
  String? localPath,
});

AttachmentFileKey attachmentFileKeyOf(NoteAttachment attachment) => (
  noteId: attachment.noteId,
  attachmentId: attachment.id,
  filename: attachment.originalFilename,
  localPath: attachment.localPath,
);

AttachmentFileKey previewFileKeyOf(NoteImagePreview preview) => (
  noteId: preview.noteId,
  attachmentId: preview.attachmentId,
  filename: preview.filename,
  localPath: preview.localPath,
);

/// Null while offline with no copy here. Never retries on its own; reloads
/// once back online.
@Riverpod(retry: _noRetry)
FutureOr<String?> attachmentFile(Ref ref, AttachmentFileKey key) {
  final local = key.localPath;
  if (local != null && _hasBytes(local)) return local;
  ref.listen(isOnlineProvider, (wasOnline, isOnline) {
    if (isOnline && wasOnline != true) ref.invalidateSelf();
  });
  if (!ref.read(isOnlineProvider)) return null;
  return ref
      .read(noteAttachmentsRepositoryProvider)
      .downloadAttachment(key.noteId, key.attachmentId, key.filename);
}

bool _hasBytes(String path) {
  final file = File(path);
  return file.existsSync() && file.lengthSync() > 0;
}

Duration? _noRetry(int retryCount, Object error) => null;
