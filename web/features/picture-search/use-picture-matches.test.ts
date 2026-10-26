import { describe, expect, it } from "vitest";
import type { Note } from "@/features/notes/types";
import { notesForMatches } from "./use-picture-matches";

const note = (id: string) => ({ id }) as Note;
const match = (noteId: string, score: number) => ({
  noteId,
  attachmentId: `${noteId}-pic`,
  score,
});

describe("notesForMatches", () => {
  it("lists the matched notes best first, without those already shown", () => {
    const notes = [note("cats"), note("tiger"), note("street")];

    const found = notesForMatches(
      [match("tiger", 0.13), match("cats", 0.09), match("street", 0.07)],
      notes,
      [note("street")],
    );

    expect(found.map((n) => n.id)).toEqual(["tiger", "cats"]);
  });

  it("skips notes this list doesn't hold (another tag, trashed)", () => {
    expect(
      notesForMatches([match("elsewhere", 0.2)], [note("cats")], []),
    ).toEqual([]);
  });
});
