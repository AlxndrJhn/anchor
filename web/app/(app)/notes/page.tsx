"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Archive,
  ArchiveRestore,
  Hash,
  Images,
  Lock,
  Palette,
  Pin,
  PinOff,
  Plus,
  Snowflake,
  Tag as TagIcon,
  Trash2,
  X,
} from "lucide-react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import * as React from "react";
import { AppPage, Fab, PageTitle } from "@/components/layout/app-page";
import { newNoteHref } from "@/components/layout/sidebar";
import { Button, IconButton } from "@/components/ui/button";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { EmptyState, LoadFailedState } from "@/components/ui/empty-state";
import { SelectionBar } from "@/components/ui/selection-bar";
import { toast } from "@/components/ui/toast";
import { Tip } from "@/components/ui/tooltip";
import {
  bulkArchiveNotes,
  bulkDeleteNotes,
  bulkPinNotes,
  getArchivedNotes,
  getNotes,
  restoreNote,
  setNotePosition,
  unarchiveNote,
} from "@/features/notes/api";
import { BulkColorPicker } from "@/features/notes/components/bulk-color-picker";
import { BulkTagPicker } from "@/features/notes/components/bulk-tag-picker";
import { BulkLockDialog } from "@/features/notes/components/lock/bulk-lock-dialog";
import {
  NoSearchResults,
  NoteListActions,
} from "@/features/notes/components/note-list-actions";
import {
  NotesBoard,
  NotesBoardSkeleton,
} from "@/features/notes/components/notes-board";
import { ShareDialog } from "@/features/notes/components/share-dialog";
import {
  isOwnFrozen,
  useApplyFreeze,
} from "@/features/notes/hooks/use-note-freeze";
import {
  matchesSearch,
  useNoteList,
} from "@/features/notes/hooks/use-note-list";
import { useUnlockedIds } from "@/features/notes/hooks/use-note-lock";
import { useRefreshNotes } from "@/features/notes/hooks/use-refresh-notes";
import { matchesFilters } from "@/features/notes/note-filters";
import { isLockHidden } from "@/features/notes/note-lock";
import { compareNotes, positionBetween } from "@/features/notes/sort";
import { deletedNotesText, deleteNotesWarning } from "@/features/notes/trash";
import type { Note } from "@/features/notes/types";
import { usePictureMatches } from "@/features/picture-search/use-picture-matches";
import { tagColorStyle, useTagMap } from "@/features/tags";
import { burnNoteCards } from "@/lib/destroy";
import { eachLimited } from "@/lib/each";
import { useShortcuts } from "@/lib/hooks/use-shortcuts";
import { rememberNewNoteButton } from "@/lib/morph";
import { plural } from "@/lib/utils";

const NO_NOTES: Note[] = [];
const NO_PICKS = new Set<string>();

export default function NotesPage() {
  const tagId = useSearchParams().get("tagId");
  // Next keeps the page mounted when only the tag changes.
  return <NotesView key={tagId ?? ""} tagId={tagId} />;
}

function NotesView({ tagId }: { tagId: string | null }) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const refresh = useRefreshNotes();
  const tagMap = useTagMap();
  const tag = tagId ? tagMap.get(tagId) : undefined;
  const [tagAnchor, setTagAnchor] = React.useState<HTMLElement | null>(null);
  const [colorAnchor, setColorAnchor] = React.useState<HTMLElement | null>(
    null,
  );
  const [sharingNote, setSharingNote] = React.useState<Note | null>(null);
  const [locking, setLocking] = React.useState(false);
  const unlocked = useUnlockedIds();
  const [confirmRemove, setConfirmRemove] = React.useState<{
    ids: string[];
    sharedCount: number;
  } | null>(null);

  const { data, isLoading, isError, isFetching, refetch } = useQuery({
    queryKey: ["notes", tagId],
    queryFn: () => getNotes({ tagId: tagId || undefined }),
  });
  const notes = data ?? NO_NOTES;
  const loadFailed = isError && !data;
  const list = useNoteList(notes, { pinnedFirst: true });
  const { visible, pinned, others, chosen } = list;

  // A search, or a tag (whose count includes them), also lists archived
  // notes, after the others.
  const withArchived = list.searching || !!tagId;
  const { data: archivedNotes } = useQuery({
    queryKey: ["notes", "archived"],
    queryFn: getArchivedNotes,
    enabled: withArchived,
  });
  const archivedMatches = React.useMemo(
    () =>
      withArchived && archivedNotes
        ? archivedNotes
            .filter(
              (n) =>
                (!tagId || n.tagIds?.includes(tagId)) &&
                matchesSearch(n, list.term, unlocked) &&
                matchesFilters(n, list.filters),
            )
            .sort(compareNotes(list.sortBy, list.sortOrder))
        : NO_NOTES,
    [
      withArchived,
      archivedNotes,
      list.term,
      list.filters,
      tagId,
      list.sortBy,
      list.sortOrder,
      unlocked,
    ],
  );

  // Notes whose pictures look like the search, for those who turned
  // picture search on: after the notes that match by their words. A locked
  // note's pictures stay out of it until it is unlocked.
  const pictureCandidates = React.useMemo(
    () =>
      [
        ...notes,
        ...(withArchived && archivedNotes
          ? archivedNotes.filter((n) => !tagId || n.tagIds?.includes(tagId))
          : []),
      ].filter(
        (n) => matchesFilters(n, list.filters) && !isLockHidden(n, unlocked),
      ),
    [notes, withArchived, archivedNotes, tagId, list.filters, unlocked],
  );
  const shownNotes = React.useMemo(
    () => [...visible, ...archivedMatches],
    [visible, archivedMatches],
  );
  const pictureMatches = usePictureMatches(
    list.searching ? list.term : "",
    pictureCandidates,
    shownNotes,
  );

  const allPinned = chosen.length > 0 && chosen.every((n) => n.isPinned);

  /**
   * A note let go at a new place, as in Google Keep: it goes between its new
   * neighbours, and stays there until it is next edited.
   */
  // Pinned or unpinned from its card: it moves to its section at once.
  const prepareCardMotion = list.prepareCardMotion;
  const togglePin = React.useCallback(
    (note: Note) => {
      const isPinned = !note.isPinned;
      const place = (pinned: boolean) =>
        queryClient.setQueriesData<unknown>(
          { queryKey: ["notes"] },
          (data: unknown) =>
            Array.isArray(data)
              ? (data as Note[]).map((n) =>
                  n.id === note.id ? { ...n, isPinned: pinned } : n,
                )
              : data,
        );
      prepareCardMotion();
      place(isPinned);
      bulkPinNotes([note.id], isPinned)
        .catch(() => {
          prepareCardMotion();
          place(!isPinned);
          toast.error(
            isPinned ? "Couldn’t pin the note" : "Couldn’t unpin the note",
          );
        })
        .finally(() => refresh());
    },
    [prepareCardMotion, queryClient, refresh],
  );

  const reorderNote = (noteId: string, ids: string[]) => {
    const index = ids.indexOf(noteId);
    const byId = new Map(notes.map((n) => [n.id, n]));
    const position = positionBetween(
      byId.get(ids[index - 1]),
      byId.get(ids[index + 1]),
    );
    const before = byId.get(noteId);
    const place = (fields: Pick<Note, "position" | "positionedAt">) =>
      queryClient.setQueriesData<unknown>(
        { queryKey: ["notes"] },
        (data: unknown) =>
          Array.isArray(data)
            ? (data as Note[]).map((n) =>
                n.id === noteId ? { ...n, ...fields } : n,
              )
            : data,
      );
    place({ position, positionedAt: new Date().toISOString() });
    setNotePosition(noteId, position).catch(() => {
      list.prepareCardMotion();
      place({
        position: before?.position ?? null,
        positionedAt: before?.positionedAt ?? null,
      });
      toast.error("Couldn’t move the note", {
        retry: () => reorderNote(noteId, ids),
      });
    });
  };

  const noteAction = useMutation({
    mutationFn: async ({
      kind,
      ids,
    }: {
      kind: "pin" | "unpin" | "archive" | "trash";
      ids: string[];
    }) => {
      if (kind === "pin" || kind === "unpin")
        await bulkPinNotes(ids, kind === "pin");
      else if (kind === "archive") await bulkArchiveNotes(ids);
      else {
        // Deleted cards burn away in place; the others move up after.
        const burn = burnNoteCards(ids);
        await burn.done;
        list.prepareCardMotion();
        await bulkDeleteNotes(ids).catch((error: unknown) => {
          burn.restore();
          throw error;
        });
      }
    },
    onMutate: ({ kind, ids }) => {
      if (kind === "trash") setConfirmRemove(null);
      else list.prepareCardMotion();
      return {
        ownedIds: ids.filter(
          (id) => notes.find((n) => n.id === id)?.permission === "owner",
        ),
      };
    },
    onSuccess: (_, { kind, ids }, context) => {
      refresh();
      list.stopPicking();
      setConfirmRemove(null);
      const undo = async (run: () => Promise<unknown>) => {
        list.prepareCardMotion();
        try {
          await run();
        } catch {
          toast.error("Couldn’t undo that");
        }
        refresh();
      };
      if (kind === "pin" || kind === "unpin")
        toast.success(
          `${plural(ids.length, "note")} ${kind === "pin" ? "pinned" : "unpinned"}`,
          {
            undo: () => undo(() => bulkPinNotes(ids, kind !== "pin")),
          },
        );
      else if (kind === "archive")
        toast.success(`${plural(ids.length, "note")} archived`, {
          undo: () => undo(() => eachLimited(ids, unarchiveNote)),
        });
      else {
        const ownedIds = context?.ownedIds ?? [];
        toast.success(
          deletedNotesText(ownedIds.length, ids.length - ownedIds.length),
          ownedIds.length
            ? { undo: () => undo(() => eachLimited(ownedIds, restoreNote)) }
            : undefined,
        );
      }
    },
    onError: (_, { kind, ids }) => {
      const verb = {
        pin: "pin",
        unpin: "unpin",
        archive: "archive",
        trash: "delete",
      }[kind];
      toast.error(`Couldn’t ${verb} ${ids.length === 1 ? "note" : "notes"}`, {
        retry: () => noteAction.mutate({ kind, ids }),
      });
    },
  });

  const deleteChosen = () => {
    // Frozen notes stay where they are.
    const deletable = chosen.filter((n) => !isOwnFrozen(n));
    if (!deletable.length) {
      toast.info("Frozen notes can’t be deleted; unfreeze them first");
      return;
    }
    const ids = deletable.map((n) => n.id);
    const sharedCount = deletable.filter(
      (n) => n.permission !== "owner",
    ).length;
    if (sharedCount) setConfirmRemove({ ids, sharedCount });
    else noteAction.mutate({ kind: "trash", ids });
  };

  const applyFreeze = useApplyFreeze();
  const ownChosen = chosen.filter((n) => n.permission === "owner");
  const allFrozen = ownChosen.length > 0 && ownChosen.every((n) => n.isFrozen);
  const freezeChosen = () => {
    const isFrozen = !allFrozen;
    const ids = ownChosen
      .filter((n) => !!n.isFrozen !== isFrozen)
      .map((n) => n.id);
    list.stopPicking();
    applyFreeze(ids, isFrozen).then(
      () =>
        toast.success(
          `${plural(ids.length, "note")} ${isFrozen ? "frozen" : "unfrozen"}`,
          {
            undo: () =>
              void applyFreeze(ids, !isFrozen).catch(() =>
                toast.error("Couldn’t undo that"),
              ),
          },
        ),
      () =>
        toast.error(
          `Couldn’t ${isFrozen ? "freeze" : "unfreeze"} ${ids.length === 1 ? "note" : "notes"}`,
        ),
    );
  };

  const newNote = newNoteHref("/notes", tagId);
  useShortcuts({
    c: () => router.push(newNote),
    l: () => router.push(newNoteHref("/notes", tagId, { list: true })),
  });
  const noNotes =
    !isLoading && !loadFailed && notes.length === 0 && !archivedMatches.length;
  const noResults =
    notes.length > 0 &&
    visible.length === 0 &&
    !archivedMatches.length &&
    !pictureMatches.length;
  // A tag's count includes its archived notes, like the sidebar's.
  const count =
    isLoading || loadFailed
      ? undefined
      : visible.length + (tagId ? archivedMatches.length : 0);
  const newNoteButton = (
    <Button asChild>
      <Link
        href={newNote}
        data-new-note="empty"
        onClick={(e) => rememberNewNoteButton(e.currentTarget)}
      >
        <Plus aria-hidden />
        New note
      </Link>
    </Button>
  );

  const title = tag ? (
    <div className="flex min-w-0 items-center gap-1">
      <PageTitle
        count={count}
        icon={
          <span
            aria-hidden
            style={tagColorStyle(tag.color)}
            className="tag-color inline-grid text-(--hash) [&_svg]:size-5.25 [&_svg]:stroke-[2.75]"
          >
            <Hash />
          </span>
        }
      >
        {tag.name}
      </PageTitle>
      <Tip label="Show all notes">
        <IconButton
          size="sm"
          label="Show all notes"
          onClick={() => router.push("/notes")}
        >
          <X />
        </IconButton>
      </Tip>
    </div>
  ) : (
    <PageTitle count={count}>Notes</PageTitle>
  );

  const removeCount = confirmRemove?.ids.length ?? 0;
  const removeSharedCount = confirmRemove?.sharedCount ?? 0;
  return (
    <>
      <AppPage
        scrollKey={`notes:${tagId ?? ""}`}
        title={title}
        actions={
          !noNotes &&
          !loadFailed && (
            <NoteListActions
              list={list}
              placeholder={tag ? `Search #${tag.name}` : "Search notes"}
              autoFocus={searchParams.has("search")}
              showTagFilter={!tagId}
            />
          )
        }
      >
        <NotesBoardSkeleton loading={isLoading} />
        {loadFailed && (
          <LoadFailedState
            title="Couldn’t load your notes"
            onRetry={() => refetch()}
            isRetrying={isFetching}
          />
        )}
        {noNotes &&
          (tag ? (
            <EmptyState
              illustration="notes"
              title={`No notes tagged #${tag.name}`}
              action={newNoteButton}
            >
              New notes you create here get this tag.
            </EmptyState>
          ) : (
            <EmptyState
              illustration="notes"
              title="No notes yet"
              action={newNoteButton}
            >
              Create a note, or import your notes from Google Keep or Markdown
              in Settings.
            </EmptyState>
          ))}
        {noResults && <NoSearchResults list={list} />}
        {visible.length > 0 && (
          <NotesBoard
            searchTerm={list.term || undefined}
            onReorder={
              list.sortBy === "updatedAt" &&
              list.sortOrder === "desc" &&
              !list.searching &&
              !list.picking
                ? reorderNote
                : undefined
            }
            ref={list.boardRef}
            layout={list.layout}
            picking={list.picking}
            picked={list.picked}
            onPick={list.onPick}
            onShare={setSharingNote}
            onTogglePin={togglePin}
            groups={[
              ...(pinned.length
                ? [
                    {
                      key: "pinned",
                      label: "Pinned",
                      icon: <Pin aria-hidden />,
                      notes: pinned,
                    },
                  ]
                : []),
              ...(others.length
                ? [
                    {
                      key: "others",
                      label: pinned.length ? "Others" : undefined,
                      notes: others,
                    },
                  ]
                : []),
            ]}
          />
        )}
        {archivedMatches.length > 0 && !list.picking && (
          <NotesBoard
            searchTerm={list.term || undefined}
            layout={list.layout}
            picking={false}
            picked={NO_PICKS}
            onShare={setSharingNote}
            onTogglePin={togglePin}
            groups={[
              {
                key: "archived",
                label: "Archived",
                icon: <ArchiveRestore aria-hidden />,
                notes: archivedMatches,
              },
            ]}
          />
        )}
        {pictureMatches.length > 0 && !list.picking && (
          <NotesBoard
            layout={list.layout}
            picking={false}
            picked={NO_PICKS}
            onShare={setSharingNote}
            onTogglePin={togglePin}
            groups={[
              {
                key: "pictures",
                label: "Pictures that may match",
                icon: <Images aria-hidden />,
                notes: pictureMatches,
              },
            ]}
          />
        )}
      </AppPage>

      {!list.picking && (
        <Fab label="New note" asChild>
          <Link
            href={newNote}
            data-new-note="fab"
            onClick={(e) => rememberNewNoteButton(e.currentTarget)}
          >
            <Plus aria-hidden />
          </Link>
        </Fab>
      )}

      <SelectionBar
        open={list.picking}
        count={chosen.length}
        total={list.shown.length}
        onToggleAll={list.toggleAll}
        onClose={list.stopPicking}
        actions={[
          {
            key: "tag",
            label: "Tag",
            icon: <TagIcon aria-hidden />,
            onClick: (button) =>
              setTagAnchor((current) => (current ? null : button)),
          },
          {
            key: "color",
            label: "Colour",
            icon: <Palette aria-hidden />,
            onClick: (button) =>
              setColorAnchor((current) => (current ? null : button)),
          },
          allPinned
            ? {
                key: "unpin",
                label: "Unpin",
                icon: <PinOff aria-hidden />,
                onClick: () =>
                  noteAction.mutate({
                    kind: "unpin",
                    ids: chosen.map((n) => n.id),
                  }),
              }
            : {
                key: "pin",
                label: "Pin",
                icon: <Pin aria-hidden />,
                onClick: () =>
                  noteAction.mutate({
                    kind: "pin",
                    ids: chosen.filter((n) => !n.isPinned).map((n) => n.id),
                  }),
              },
          {
            key: "lock",
            label: "Lock…",
            icon: <Lock aria-hidden />,
            onClick: () => setLocking(true),
          },
          ...(ownChosen.length
            ? [
                {
                  key: "freeze",
                  label: allFrozen ? "Unfreeze" : "Freeze",
                  icon: <Snowflake aria-hidden />,
                  onClick: freezeChosen,
                },
              ]
            : []),
          {
            key: "archive",
            label: "Archive",
            icon: <Archive aria-hidden />,
            onClick: () =>
              noteAction.mutate({
                kind: "archive",
                ids: chosen.map((n) => n.id),
              }),
          },
          {
            key: "delete",
            label: "Delete",
            icon: <Trash2 aria-hidden />,
            onClick: deleteChosen,
          },
        ]}
      />

      <ConfirmationDialog
        open={!!confirmRemove}
        onOpenChange={(open) => !open && setConfirmRemove(null)}
        title={`Delete ${plural(removeCount, "note")}?`}
        description={deleteNotesWarning(
          removeCount - removeSharedCount,
          removeSharedCount,
        )}
        confirmLabel="Delete"
        busyLabel="Deleting…"
        isPending={noteAction.isPending}
        onConfirm={() =>
          confirmRemove &&
          noteAction.mutate({ kind: "trash", ids: confirmRemove.ids })
        }
      />

      <BulkColorPicker
        anchor={colorAnchor}
        notes={chosen}
        onClose={() => setColorAnchor(null)}
        onDone={list.stopPicking}
      />
      <BulkLockDialog
        notes={chosen}
        open={locking}
        onOpenChange={setLocking}
        onDone={list.stopPicking}
      />
      <BulkTagPicker
        anchor={tagAnchor}
        notes={chosen}
        onClose={() => setTagAnchor(null)}
      />
      {sharingNote && (
        <ShareDialog
          open
          noteId={sharingNote.id}
          title={sharingNote.title}
          onOpenChange={(open) => !open && setSharingNote(null)}
        />
      )}
    </>
  );
}
