import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_attachment.freezed.dart';
part 'note_attachment.g.dart';

enum AttachmentType {
  image,
  audio,

  /// Any other kind of file: a document, an archive, a zipped folder.
  file;

  static AttachmentType fromString(String value) {
    return AttachmentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AttachmentType.file,
    );
  }

  /// How a file of [mimeType] shows in a note, as the server decides.
  static AttachmentType forMimeType(String mimeType) {
    if (imageMimeTypes.contains(mimeType)) return AttachmentType.image;
    if (audioMimeTypes.contains(mimeType)) return AttachmentType.audio;
    return AttachmentType.file;
  }

  /// Pictures shown in the note.
  static const imageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  /// Recordings played in the note.
  static const audioMimeTypes = {
    'audio/mpeg',
    'audio/wav',
    'audio/mp4',
    'audio/x-m4a',
    'audio/ogg',
    'audio/aac',
    'audio/webm',
  };
}

/// Sync status for attachments (stored in DB as text).
/// Values match DB column: 'synced', 'pending_upload', 'pending_delete'.
enum AttachmentSyncStatus {
  synced('synced'),
  pendingUpload('pending_upload'),
  pendingDelete('pending_delete');

  const AttachmentSyncStatus(this.dbValue);
  final String dbValue;

  static AttachmentSyncStatus fromString(String value) {
    return AttachmentSyncStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => AttachmentSyncStatus.synced,
    );
  }
}

@freezed
abstract class NoteAttachment with _$NoteAttachment {
  const NoteAttachment._();

  const factory NoteAttachment({
    required String id,
    required String noteId,
    required AttachmentType type,
    required String originalFilename,
    required String mimeType,
    required int fileSize,
    @Default(0) int position,
    // Text the server read from a picture, for search.
    String? text,
    String? uploadedByUserId,
    // Local only - not from server
    @JsonKey(includeFromJson: false, includeToJson: false) String? localPath,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool isPendingUpload,
    String? createdAt,
  }) = _NoteAttachment;

  factory NoteAttachment.fromJson(Map<String, dynamic> json) =>
      _$NoteAttachmentFromJson(json);

  bool get isImage => type == AttachmentType.image;
  bool get isAudio => type == AttachmentType.audio;
  bool get isFile => type == AttachmentType.file;
}
