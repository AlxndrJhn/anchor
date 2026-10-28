import type { Note } from 'src/generated/prisma/client';
import type { NoteState } from 'src/generated/prisma/enums';

// Only these fields bump Note.version. Pins, reminders, tag reconciliation,
// and attachment touches never do.
export interface GuardedNoteFields {
  title?: string;
  content?: string | null;
  background?: string | null;
  state?: NoteState;
  isFrozen?: boolean;
}

export const guardedNoteFieldsChanged = (
  prior: Note,
  data: GuardedNoteFields,
) =>
  noteContentChanged(prior, data) ||
  (data.background !== undefined && data.background !== prior.background) ||
  (data.state !== undefined && data.state !== prior.state) ||
  (data.isFrozen !== undefined && data.isFrozen !== prior.isFrozen);

export const noteContentChanged = (prior: Note, data: GuardedNoteFields) =>
  (data.title !== undefined && data.title !== prior.title) ||
  (data.content !== undefined && data.content !== prior.content);
