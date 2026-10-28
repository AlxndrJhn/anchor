/** Where the caret was in a note: its title or its text. */
export type NoteCaret = {
  field: "title" | "content";
  index: number;
  length: number;
};

// Kept across the note closing, for the next time it opens.
const pending = new Map<string, NoteCaret>();

/** The note opens next with the caret at [caret]. */
export function returnCaretTo(noteId: string, caret: NoteCaret) {
  pending.set(noteId, caret);
}

export function hasReturnCaret(noteId: string) {
  return pending.has(noteId);
}

/** The caret the note should open with, once. */
export function takeReturnCaret(noteId: string): NoteCaret | null {
  const caret = pending.get(noteId) ?? null;
  pending.delete(noteId);
  return caret;
}

/** [caret] fitted into a field [size] characters long. */
export function clampCaret(caret: NoteCaret, size: number): NoteCaret {
  const index = Math.max(0, Math.min(caret.index, size));
  return {
    ...caret,
    index,
    length: Math.max(0, Math.min(caret.length, size - index)),
  };
}
