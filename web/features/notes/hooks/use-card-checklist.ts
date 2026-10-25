"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { toast } from "@/components/ui/toast";
import { usePreferencesStore } from "@/features/preferences";
import { saveNote } from "../api";
import { toggleChecklistItem } from "../quill-checklist";
import type { Note } from "../types";

/** Whether this person may tick a note's items from its card. */
export function canTickFromCard(note: Note) {
  return (
    note.permission !== "viewer" && note.state !== "trashed" && !note.isArchived
  );
}

/**
 * Ticks or unticks a checklist item from a note's card, without opening the
 * note: the lists show it at once, then it is saved on top of the note's
 * version, and re-applied once if someone else changed the note meanwhile.
 */
export function useCardChecklist() {
  const queryClient = useQueryClient();
  const sort = usePreferencesStore((s) => s.editor.sortChecklistItems);

  const putInLists = useCallback(
    (note: Note) => {
      queryClient.setQueriesData<Note[]>({ queryKey: ["notes"] }, (list) =>
        Array.isArray(list)
          ? list.map((n) => (n.id === note.id ? { ...n, ...note } : n))
          : list,
      );
      queryClient.setQueryData<Note>(["notes", note.id], (old) =>
        old ? { ...old, ...note } : old,
      );
    },
    [queryClient],
  );

  return useCallback(
    async (note: Note, line: number) => {
      const content = toggleChecklistItem(note.content, line, sort);
      if (content === null) return;
      putInLists({ ...note, content });

      let outcome = await saveNote(note.id, {
        content,
        baseVersion: note.version,
      });
      if (outcome.status === "conflict") {
        const again = toggleChecklistItem(
          outcome.serverNote.content,
          line,
          sort,
        );
        outcome = again
          ? await saveNote(note.id, {
              content: again,
              baseVersion: outcome.serverNote.version,
            })
          : outcome;
      }
      if (outcome.status === "saved") putInLists(outcome.note);
      else {
        putInLists(note);
        toast.error("Couldn’t save that tick. Open the note to try again.");
      }
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
    [putInLists, queryClient, sort],
  );
}
