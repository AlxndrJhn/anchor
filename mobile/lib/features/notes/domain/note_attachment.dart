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
  static AttachmentType fromMimeType(String mimeType) {
    if (imageMimeTypes.contains(mimeType)) return AttachmentType.image;
    if (audioMimeTypes.contains(mimeType)) return AttachmentType.audio;
    return AttachmentType.file;
  }

  /// Pictures shown in the note; the server's list.
  static const imageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  /// Recordings played in the note; the server's list.
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

const recordingFilePrefix = 'recording_';

enum AttachmentKind {
  picture,
  voiceNote,
  audioFile,
  file;

  static AttachmentKind of({
    required String mimeType,
    required String filename,
  }) => switch (AttachmentType.fromMimeType(mimeType)) {
    AttachmentType.image => AttachmentKind.picture,
    AttachmentType.audio when filename.startsWith(recordingFilePrefix) =>
      AttachmentKind.voiceNote,
    AttachmentType.audio => AttachmentKind.audioFile,
    AttachmentType.file => AttachmentKind.file,
  };
}

/// Must match the server's limit.
const maxAttachmentBytes = 50 * 1024 * 1024;

class AttachmentTooBigException implements Exception {
  const AttachmentTooBigException();
}

enum AttachmentSyncStatus {
  synced('synced'),
  pendingUpload('pending_upload'),
  uploadFailed('upload_failed'),
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
    @JsonKey(includeFromJson: false, includeToJson: false) String? localPath,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool isPendingUpload,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool isUploadFailed,
    String? createdAt,
  }) = _NoteAttachment;

  factory NoteAttachment.fromJson(Map<String, dynamic> json) =>
      _$NoteAttachmentFromJson(json);

  bool get isImage => type == AttachmentType.image;
  bool get isAudio => type == AttachmentType.audio;
  bool get isFile => type == AttachmentType.file;

  AttachmentKind get kind =>
      AttachmentKind.of(mimeType: mimeType, filename: originalFilename);
}
