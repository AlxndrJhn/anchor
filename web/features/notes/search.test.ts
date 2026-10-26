import { describe, expect, it } from "vitest";
import { matchesSearch } from "./search";
import type { Note } from "./types";

const note = (fields: Partial<Note>) =>
  ({
    title: "Groceries",
    content: JSON.stringify({ ops: [{ insert: "Milk and bread\n" }] }),
    ...fields,
  }) as Note;

describe("matchesSearch", () => {
  it("finds the term in the title or the text", () => {
    expect(matchesSearch(note({}), "groceries")).toBe(true);
    expect(matchesSearch(note({}), "bread")).toBe(true);
    expect(matchesSearch(note({}), "dentist")).toBe(false);
  });

  it("finds the term in the text read from the note's pictures", () => {
    const withPicture = note({ pictureText: "Call the Dentist on Monday" });
    expect(matchesSearch(withPicture, "dentist")).toBe(true);
    expect(matchesSearch(note({}), "dentist")).toBe(false);
  });

  it("matches everything without a term", () => {
    expect(matchesSearch(note({}), "")).toBe(true);
  });
});
