"use client";

import { type QueryClient, useQueryClient } from "@tanstack/react-query";
import * as React from "react";
import { bulkInvisibleNotes, setNoteInvisible } from "../api";
import type { Note } from "../types";

function patchCachedInvisible(
  queryClient: QueryClient,
  ids: string[],
  isInvisible: boolean,
) {
  const wanted = new Set(ids);
  const patch = (n: Note) => (wanted.has(n.id) ? { ...n, isInvisible } : n);
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
 * Makes notes invisible for this person, or shows them again: the lists
 * change at once, and go back if the server turns it down.
 */
export function useApplyInvisible() {
  const queryClient = useQueryClient();
  return React.useCallback(
    async (ids: string[], isInvisible: boolean): Promise<void> => {
      if (!ids.length) return;
      patchCachedInvisible(queryClient, ids, isInvisible);
      try {
        if (ids.length === 1) await setNoteInvisible(ids[0], isInvisible);
        else await bulkInvisibleNotes(ids, isInvisible);
      } catch (error) {
        patchCachedInvisible(queryClient, ids, !isInvisible);
        throw error;
      } finally {
        void queryClient.invalidateQueries({ queryKey: ["notes"] });
      }
    },
    [queryClient],
  );
}
