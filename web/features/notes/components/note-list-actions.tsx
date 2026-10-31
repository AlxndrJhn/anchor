"use client";

import { CircleCheck } from "lucide-react";
import type * as React from "react";
import { SearchField, TopBarButton } from "@/components/layout/app-page";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import type { NoteList } from "../hooks/use-note-list";
import { FilterMenu } from "./filter-menu";
import { ViewOptions } from "./view-options";

export function NoteListActions({
  list,
  placeholder,
  autoFocus,
  showTagFilter,
  onSearchFocus,
  children,
}: {
  list: NoteList;
  placeholder: string;
  autoFocus?: boolean;
  /** Off in a tag's own view. */
  showTagFilter?: boolean;
  onSearchFocus?: () => void;
  children?: React.ReactNode;
}) {
  return (
    <>
      <SearchField
        ref={list.searchRef}
        value={list.query}
        onChange={list.setQuery}
        placeholder={placeholder}
        autoFocus={autoFocus}
        onFocus={onSearchFocus}
      />
      <FilterMenu list={list} showTags={showTagFilter} />
      <ViewOptions
        layout={list.layout}
        sortBy={list.sortBy}
        sortOrder={list.sortOrder}
        onLayout={list.setLayout}
        onSort={list.setSort}
        showPictures={list.showPictures}
        onShowPictures={list.setShowPictures}
      />
      <TopBarButton
        icon={<CircleCheck aria-hidden />}
        aria-pressed={list.picking}
        onClick={list.togglePicking}
      >
        Select
      </TopBarButton>
      {children}
    </>
  );
}

export function NoSearchResults({ list }: { list: NoteList }) {
  const query = list.query.trim();
  const filtered = list.activeFilters > 0;
  return (
    <EmptyState
      illustration="search"
      title={query ? `No results for “${query}”` : "No matching notes"}
      action={
        <Button
          variant="secondary"
          onClick={() => {
            list.setQuery("");
            list.setFilters({});
            list.searchRef.current?.focus();
          }}
        >
          {filtered && query
            ? "Clear search and filters"
            : filtered
              ? "Clear filters"
              : "Clear search"}
        </Button>
      }
    >
      {filtered
        ? "No note matches every filter."
        : "Check the spelling or try different words."}
    </EmptyState>
  );
}
