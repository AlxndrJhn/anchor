import type { NoteAttachment } from 'src/generated/prisma/client';

export class AttachmentResponseDto {
  id: string;
  noteId: string;
  type: string;
  originalFilename: string;
  mimeType: string;
  fileSize: number;
  position: number;
  /** Text read from a picture, for search; null until read or if none. */
  text: string | null;
  uploadedByUserId: string;
  createdAt: Date;
}

export function toAttachmentResponse(
  attachment: NoteAttachment,
): AttachmentResponseDto {
  return {
    id: attachment.id,
    noteId: attachment.noteId,
    type: attachment.type,
    originalFilename: attachment.originalFilename,
    mimeType: attachment.mimeType,
    fileSize: attachment.fileSize,
    position: attachment.position,
    text: attachment.text,
    uploadedByUserId: attachment.uploadedByUserId,
    createdAt: attachment.createdAt,
  };
}
