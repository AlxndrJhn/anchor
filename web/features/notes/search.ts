import { hasSearchTerm } from "@/lib/search-pattern";
import { isLockHidden } from "./note-lock";
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

const NONE_UNLOCKED: ReadonlySet<string> = new Set();

/**
 * Whether a note's title, text or pictures have the (trimmed) term, in any
 * case and with or without accents. A note locked and not opened this
 * session (see `unlocked`) is found by its title only, so a search can't
 * tell what it says.
 */
export function matchesSearch(
  note: Note,
  term: string,
  unlocked: ReadonlySet<string> = NONE_UNLOCKED,
) {
  if (!term) return true;
  if (isLockHidden(note, unlocked)) return hasSearchTerm(note.title, term);
  return hasSearchTerm(searchTextOf(note), term);
}
