import type { QuillDelta } from "@/features/notes/quill";

// Accents NFC can join into the letter before them: Latin, Greek and
// Cyrillic accents, Hangul vowels and final consonants, kana voicing marks.
const JOINING_MARK =
  /[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F\u1160-\u11FF\u3099\u309A]/;

/**
 * Text with each accent joined into its letter (Unicode NFC), as typing
 * stores it. macOS file and folder names keep "ệ" as e plus two accents,
 * which the mobile app's fonts without "ệ" draw apart. Mirrors
 * composedText in the mobile app: text without such an accent stays as it
 * came.
 */
export const composedText = (text: string) =>
  JOINING_MARK.test(text) ? text.normalize("NFC") : text;

export const composedDelta = (delta: QuillDelta): QuillDelta => ({
  ...delta,
  ops: delta.ops.map((op) =>
    typeof op.insert === "string"
      ? { ...op, insert: composedText(op.insert) }
      : op,
  ),
});
