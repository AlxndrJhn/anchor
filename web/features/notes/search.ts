import { deltaToFullPlainText } from "./quill";
import type { Note } from "./types";

const searchTextByNote = new WeakMap<Note, string>();

function searchTextOf(note: Note) {
  let text = searchTextByNote.get(note);
  if (text === undefined) {
    text =
      `${note.title}\n${deltaToFullPlainText(note.content)}\n${note.pictureText ?? ""}`.toLowerCase();
    searchTextByNote.set(note, text);
  }
  return text;
}

/** Whether a note's title, text or pictures have the (lowercase, trimmed) term. */
export function matchesSearch(note: Note, term: string) {
  return !term || searchTextOf(note).includes(term);
}
