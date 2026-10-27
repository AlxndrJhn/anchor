"use client";

import { useSearchParams } from "next/navigation";
import * as React from "react";
import {
  type SortBy,
  type SortOrder,
  usePreferencesStore,
  type ViewMode,
} from "@/features/preferences";
import { NOTES_WILL_CHANGE } from "@/lib/destroy";
import { hasOverlay, isTypingTarget } from "@/lib/hooks/use-shortcuts";
import { hasShortcutKey } from "@/lib/platform";
import { useFlip } from "@/lib/use-flip";
import {
  filterCount,
  filtersFromParams,
  matchesFilters,
  type NoteFilters,
  writeFilterParams,
} from "../note-filters";
import { matchesSearch } from "../search";
import { compareNotes } from "../sort";
import type { Note } from "../types";

export { matchesSearch };

const SEARCH_PARAM = "q";

export function useNoteList(notes: Note[], { pinnedFirst = false } = {}) {
  const {
    viewMode,
    sortBy: storedSortBy,
    sortOrder,
    showPictures,
  } = usePreferencesStore((s) => s.notes);
  // A "Custom" sort saved by an earlier version: dragging now works in the
  // default order instead.
  const sortBy: SortBy =
    (storedSortBy as string) === "custom" ? "updatedAt" : storedSortBy;
  const setNotesPreference = usePreferencesStore((s) => s.setNotesPreference);
  const boardRef = React.useRef<HTMLDivElement>(null);
  const searchRef = React.useRef<HTMLInputElement>(null);
  const flip = useFlip(boardRef);
  // A note deleted while open burns in this list, then goes: its cards glide.
  React.useEffect(() => {
    window.addEventListener(NOTES_WILL_CHANGE, flip.prepare);
    return () => window.removeEventListener(NOTES_WILL_CHANGE, flip.prepare);
  }, [flip.prepare]);
  const searchParams = useSearchParams();
  // Kept in the address, so Back from an opened note finds the same results.
  const [query, setQueryValue] = React.useState(
    () => searchParams.get(SEARCH_PARAM) ?? "",
  );
  const [filters, setFiltersValue] = React.useState<NoteFilters>(() =>
    filtersFromParams(searchParams),
  );
  const searchedQuery = React.useDeferredValue(query);
  const term = searchedQuery.trim().toLowerCase();
  React.useEffect(() => {
    const timer = window.setTimeout(() => {
      const url = new URL(window.location.href);
      const before = url.search;
      if (query) url.searchParams.set(SEARCH_PARAM, query);
      else url.searchParams.delete(SEARCH_PARAM);
      writeFilterParams(url.searchParams, filters);
      if (url.search === before) return;
      window.history.replaceState(window.history.state, "", url);
    }, 250);
    return () => window.clearTimeout(timer);
  }, [query, filters]);
  const activeFilters = filterCount(filters);
  const [picking, setPicking] = React.useState(false);
  const [picked, setPicked] = React.useState<Set<string>>(new Set());
  const lastPick = React.useRef<string | null>(null);

  const visible = React.useMemo(() => {
    const found =
      term || activeFilters
        ? notes.filter(
            (note) =>
              matchesSearch(note, term) && matchesFilters(note, filters),
          )
        : notes;
    return [...found].sort(compareNotes(sortBy, sortOrder));
  }, [notes, term, filters, activeFilters, sortBy, sortOrder]);
  const pinned = React.useMemo(
    () => (pinnedFirst ? visible.filter((n) => n.isPinned) : []),
    [pinnedFirst, visible],
  );
  const others = React.useMemo(
    () => (pinnedFirst ? visible.filter((n) => !n.isPinned) : visible),
    [pinnedFirst, visible],
  );
  const shown = React.useMemo(
    () => (pinned.length ? [...pinned, ...others] : others),
    [pinned, others],
  );
  const shownRef = React.useRef(shown);
  React.useLayoutEffect(() => {
    shownRef.current = shown;
  });

  const stopPicking = React.useCallback(() => {
    setPicking(false);
    setPicked(new Set());
    lastPick.current = null;
  }, []);

  React.useEffect(() => {
    if (!picking) return;
    // An Esc that closed a menu, pop-over or dialog stops there.
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !e.defaultPrevented) stopPicking();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [picking, stopPicking]);

  React.useEffect(() => {
    // Select every note shown, as in Google Keep.
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.defaultPrevented || !hasShortcutKey(e) || e.altKey || e.shiftKey)
        return;
      if (e.key.toLowerCase() !== "a") return;
      if (isTypingTarget(e.target) || hasOverlay()) return;
      const ids = shownRef.current.map((n) => n.id);
      if (!ids.length) return;
      e.preventDefault();
      window.getSelection()?.removeAllRanges();
      setPicking(true);
      setPicked(new Set(ids));
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  React.useEffect(() => {
    const visibleIds = new Set(visible.map((note) => note.id));
    setPicked((prev) => {
      const kept = [...prev].filter((id) => visibleIds.has(id));
      return kept.length === prev.size ? prev : new Set(kept);
    });
  }, [visible]);

  const isEmpty = notes.length === 0;
  React.useEffect(() => {
    if (picking && isEmpty) stopPicking();
  }, [picking, isEmpty, stopPicking]);

  const onPick = React.useCallback((id: string, range: boolean) => {
    const ids = shownRef.current.map((n) => n.id);
    const from = lastPick.current ? ids.indexOf(lastPick.current) : -1;
    const to = ids.indexOf(id);
    lastPick.current = id;
    setPicking(true);
    setPicked((prev) => {
      const next = new Set(prev);
      if (range && from >= 0 && to >= 0)
        for (const rangeId of ids.slice(
          Math.min(from, to),
          Math.max(from, to) + 1,
        ))
          next.add(rangeId);
      else if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const toggleAll = () =>
    setPicked(
      picked.size === shown.length
        ? new Set()
        : new Set(shown.map((n) => n.id)),
    );
  const chosen = shown.filter((n) => picked.has(n.id));

  return {
    boardRef,
    searchRef,
    prepareCardMotion: flip.prepare,
    query,
    /** The searched term, lowercase and trimmed; lags typing a little. */
    term,
    setQuery: (value: string) => {
      flip.prepare();
      setQueryValue(value);
    },
    filters,
    /** How many filters are on. */
    activeFilters,
    setFilters: (next: NoteFilters) => {
      flip.prepare();
      setFiltersValue(next);
    },
    /** Whether a search or a filter narrows the list. */
    searching: !!term || activeFilters > 0,
    layout: viewMode,
    setLayout: (layout: ViewMode) => {
      flip.prepare();
      setNotesPreference("viewMode", layout);
    },
    sortBy,
    sortOrder,
    showPictures: showPictures !== false,
    setShowPictures: (show: boolean) => {
      flip.prepare();
      setNotesPreference("showPictures", show);
    },
    setSort: (by: SortBy, order: SortOrder) => {
      flip.prepare();
      setNotesPreference("sortBy", by);
      setNotesPreference("sortOrder", order);
    },
    visible,
    pinned,
    others,
    shown,
    picking,
    togglePicking: () => (picking ? stopPicking() : setPicking(true)),
    picked,
    chosen,
    onPick,
    toggleAll,
    stopPicking,
  };
}

export type NoteList = ReturnType<typeof useNoteList>;
