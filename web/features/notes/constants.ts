const ACCEPTED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
] as const;

const ACCEPTED_AUDIO_TYPES = [
  "audio/mpeg",
  "audio/wav",
  "audio/mp4",
  "audio/x-m4a",
  "audio/ogg",
  "audio/aac",
  "audio/webm",
] as const;

export const MAX_ATTACHMENT_SIZE = 50 * 1024 * 1024;

const IMAGE_MIME_SET = new Set<string>(ACCEPTED_IMAGE_TYPES);
const AUDIO_MIME_SET = new Set<string>(ACCEPTED_AUDIO_TYPES);

/** How an attachment of this type shows: any other file is kept as a file. */
export function attachmentKindOf(mimeType: string): "image" | "audio" | "file" {
  if (IMAGE_MIME_SET.has(mimeType)) return "image";
  if (AUDIO_MIME_SET.has(mimeType)) return "audio";
  return "file";
}
