"use client";

import { useQuery } from "@tanstack/react-query";
import * as React from "react";
import type { Note } from "@/features/notes/types";
import {
  getPictureSearchStatus,
  type PictureMatch,
  pictureSearchStatusKey,
  searchPictures,
} from "./api";

/** How long typing pauses before the server is asked. */
const PAUSE_MS = 400;

/**
 * The notes whose pictures look like the search, best first, from [notes]
 * and leaving out the ones [shown] already: for users who turned picture
 * search on, while online.
 */
export function usePictureMatches(
  term: string,
  notes: readonly Note[],
  shown: readonly Note[],
): Note[] {
  const { data: status } = useQuery({
    queryKey: pictureSearchStatusKey,
    queryFn: getPictureSearchStatus,
    staleTime: 60_000,
  });
  const [asked, setAsked] = React.useState(term);
  React.useEffect(() => {
    const timer = window.setTimeout(() => setAsked(term), PAUSE_MS);
    return () => window.clearTimeout(timer);
  }, [term]);

  const query = asked.trim();
  const { data: matches } = useQuery({
    queryKey: ["picture-search", query],
    queryFn: () => searchPictures(query),
    enabled: !!status?.enabled && query.length >= 2 && term.trim() === query,
    staleTime: 60_000,
  });

  return React.useMemo(
    () =>
      term.trim() && matches ? notesForMatches(matches, notes, shown) : [],
    [matches, notes, shown, term],
  );
}

/** The notes [matches] name, in their order, leaving out those [shown]. */
export function notesForMatches(
  matches: readonly PictureMatch[],
  notes: readonly Note[],
  shown: readonly Note[],
): Note[] {
  const byId = new Map(notes.map((n) => [n.id, n]));
  const already = new Set(shown.map((n) => n.id));
  return matches.flatMap(({ noteId }) => {
    const note = byId.get(noteId);
    return note && !already.has(noteId) ? [note] : [];
  });
}
