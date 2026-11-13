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

  it("ignores accents, typed or not", () => {
    const apples = note({ title: "Äpfel", content: null });
    expect(matchesSearch(apples, "apfel")).toBe(true);
    expect(matchesSearch(note({ title: "Apfelkuchen" }), "äpfel")).toBe(true);
    expect(matchesSearch(note({ title: "Café" }), "cafe")).toBe(true);
    expect(matchesSearch(note({ title: "Hauptstraße" }), "strasse")).toBe(true);
    expect(matchesSearch(note({ title: "STRASSE" }), "straße")).toBe(true);
    expect(matchesSearch(apples, "birne")).toBe(false);
  });

  it("treats regex characters as text", () => {
    expect(matchesSearch(note({ title: "a+b (c)" }), "+b (c")).toBe(true);
    expect(matchesSearch(note({ title: "ab" }), "a.")).toBe(false);
  });

  it("matches everything without a term", () => {
    expect(matchesSearch(note({}), "")).toBe(true);
  });

  it("finds a locked note by its text and pictures too", () => {
    const locked = note({ id: "n1", lock: "pin", pictureText: "Dentist" });
    expect(matchesSearch(locked, "groceries")).toBe(true);
    expect(matchesSearch(locked, "bread")).toBe(true);
    expect(matchesSearch(locked, "dentist")).toBe(true);
    expect(matchesSearch(locked, "birne")).toBe(false);
  });
});
