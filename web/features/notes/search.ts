import { hasSearchTerm } from "@/lib/search-pattern";
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

/**
 * Whether a note's title, text or pictures have the (trimmed) term, in any
 * case and with or without accents. Locked notes too: a lock only keeps a
 * note's text off the screen until it's opened, it isn't a secret store.
 */
export function matchesSearch(note: Note, term: string) {
  if (!term) return true;
  return hasSearchTerm(searchTextOf(note), term);
}
