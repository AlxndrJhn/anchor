"use client";

import { type QueryClient, useQueryClient } from "@tanstack/react-query";
import * as React from "react";
import { bulkFreezeNotes, setNoteFrozen } from "../api";
import type { Note } from "../types";

/** A frozen note of this person's own: it can't be trashed or changed. */
export const isOwnFrozen = (note: Pick<Note, "isFrozen" | "permission">) =>
  !!note.isFrozen && note.permission === "owner";

function patchCachedFrozen(
  queryClient: QueryClient,
  ids: string[],
  isFrozen: boolean,
) {
  const wanted = new Set(ids);
  const patch = (n: Note) => (wanted.has(n.id) ? { ...n, isFrozen } : n);
  queryClient.setQueriesData<unknown>(
    { queryKey: ["notes"] },
    (data: unknown) => {
      if (Array.isArray(data)) return (data as Note[]).map(patch);
      if (data && typeof data === "object" && "id" in data)
        return patch(data as Note);
      return data;
    },
  );
}

/**
 * Freezes or unfreezes notes the person owns: the cards change at once, and
 * go back if the server turns it down. Needs a connection.
 */
export function useApplyFreeze() {
  const queryClient = useQueryClient();
  return React.useCallback(
    async (ids: string[], isFrozen: boolean): Promise<void> => {
      if (!ids.length) return;
      patchCachedFrozen(queryClient, ids, isFrozen);
      try {
        if (ids.length === 1) {
          // The opened note takes the new version, so later saves land.
          const note = await setNoteFrozen(ids[0], isFrozen);
          queryClient.setQueryData(["notes", note.id], note);
        } else await bulkFreezeNotes(ids, isFrozen);
      } catch (error) {
        patchCachedFrozen(queryClient, ids, !isFrozen);
        throw error;
      } finally {
        void queryClient.invalidateQueries({ queryKey: ["notes"] });
      }
    },
    [queryClient],
  );
}
