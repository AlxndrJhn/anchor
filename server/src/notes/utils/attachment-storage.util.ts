import { BadRequestException } from '@nestjs/common';
import * as crypto from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { AttachmentType } from 'src/generated/prisma/enums';
import {
  ATTACHMENT_AUDIO_MIME_TYPES,
  ATTACHMENT_IMAGE_MIME_TYPES,
  ATTACHMENT_MAX_FILE_SIZE,
} from '../constants/notes.constants';

export function assertValidAttachmentFile(file?: Express.Multer.File): void {
  if (!file) {
    throw new BadRequestException('No file provided');
  }
  if (file.size > ATTACHMENT_MAX_FILE_SIZE) {
    throw new BadRequestException(
      `File size exceeds ${ATTACHMENT_MAX_FILE_SIZE / 1024 / 1024}MB limit`,
    );
  }
}

/** Pictures and recordings the clients show; anything else is a file. */
export function attachmentTypeForMime(mimeType: string): AttachmentType {
  if (ATTACHMENT_IMAGE_MIME_TYPES.has(mimeType)) return AttachmentType.image;
  if (ATTACHMENT_AUDIO_MIME_TYPES.has(mimeType)) return AttachmentType.audio;
  return AttachmentType.file;
}

/**
 * The Content-Type an attachment is served with. A file is sent as bytes to
 * download, never as something the browser would render (HTML, SVG) on the
 * app's own origin.
 */
export function servedMimeType(type: AttachmentType, mimeType: string) {
  return type === AttachmentType.file ? 'application/octet-stream' : mimeType;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** An id a client picked for its upload, if it is a usable one. */
export function clientAttachmentId(id: unknown): string | undefined {
  return typeof id === 'string' && UUID.test(id) ? id : undefined;
}

export async function writeAttachmentFile(
  noteDir: string,
  originalName: string,
  data: Buffer,
): Promise<{ storedFilename: string; filePath: string }> {
  await fs.mkdir(noteDir, { recursive: true });

  const ext = path.extname(originalName).toLowerCase();
  const storedFilename = `${crypto.randomUUID()}-${Date.now()}${ext}`;
  const filePath = path.join(noteDir, storedFilename);

  await fs.writeFile(filePath, data);
  return { storedFilename, filePath };
}
