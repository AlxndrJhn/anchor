import type { QueryClient } from "@tanstack/react-query";
import { toast } from "@/components/ui/toast";
import { createNote, isRetryableError, saveNote } from "./api";
import { type OutboxEntry, readOutbox, writeOutboxEntry } from "./outbox";
import {
  createNoteSaveQueue,
  draftUpdate,
  type NoteDraft,
  type NoteSaveQueue,
  noteDraftsEqual,
  noteToDraft,
  rebaseDraft,
  type SaveFailure,
  type SaveOutcome,
  toReminderInput,
} from "./save-queue";
import type { Note, UpdateNoteDto } from "./types";

interface EditorLink {
  buildUpdate: (draft: NoteDraft, baseVersion?: number) => UpdateNoteDto;
  onSaved: (draft: NoteDraft, note: Note) => void;
  onConflict: (
    serverNote: Note,
    draft: NoteDraft,
    canRetry: boolean,
  ) => NoteDraft | null;
  onFailed: (failure: SaveFailure) => void;
  onBusyChange: (busy: boolean) => void;
  /** The server's copy the editor's draft is made from. */
  base: () => NoteDraft | null;
  save: () => void;
  retryCreate: () => void;
  flush: () => void;
  openHistory: () => void;
}

// The app's query client, for queues that save with no editor open.
let queryClient: QueryClient | null = null;

/** Puts a note the server saved into the notes lists and its own query. */
function showSaved(note: Note) {
  if (!queryClient) return;
  queryClient.setQueryData(["notes", note.id], note);
  queryClient.setQueriesData<unknown>(
    { queryKey: ["notes"] },
    (data: unknown) =>
      Array.isArray(data)
        ? (data as Note[]).map((n) => (n.id === note.id ? note : n))
        : data,
  );
}

/** Shows an unsent draft on the note's card in every loaded list. */
function showDraft(noteId: string, draft: NoteDraft) {
  queryClient?.setQueriesData<unknown>(
    { queryKey: ["notes"] },
    (data: unknown) =>
      Array.isArray(data)
        ? (data as Note[]).map((n) =>
            n.id === noteId
              ? {
                  ...n,
                  title: draft.title,
                  content: draft.content,
                  isPinned: draft.isPinned,
                  background: draft.background,
                  tagIds: draft.tagIds,
                }
              : n,
          )
        : data,
  );
}

/** A queue's stand-in when no editor has the note open. */
function unlinkedEditor(noteId: string): EditorLink {
  return {
    buildUpdate: (draft, baseVersion) =>
      draftUpdate(draft, null, { isViewer: false, baseVersion }),
    onSaved: (_draft, note) => showSaved(note),
    // Keeps the fields changed offline and takes the rest from the server.
    // The server keeps the version this replaces in the note's history.
    onConflict: (serverNote, draft) => {
      const server = noteToDraft(serverNote);
      const base = readOutbox()[noteId]?.base ?? server;
      const next = rebaseDraft(draft, base, server);
      return noteDraftsEqual(next, server) ? null : next;
    },
    onFailed: (failure) => {
      if (failure.retryable) return;
      writeOutboxEntry(noteId, null);
      toast.error("An edit made offline couldn’t be saved.");
    },
    onBusyChange: () => {},
    base: () => null,
    save: () => {},
    retryCreate: () => {},
    flush: () => {},
    openHistory: () => {},
  };
}

/** Creates a note made offline, then saves anything newer than what it got. */
async function createThenSave(
  noteId: string,
  draft: NoteDraft,
): Promise<SaveOutcome> {
  let created: Note;
  try {
    created = await createNote({
      id: noteId,
      ...draft,
      reminder: toReminderInput(draft.reminder),
    });
  } catch (error) {
    return {
      status: "failed",
      httpStatus: null,
      retryable: isRetryableError(error),
    };
  }
  const entry = readOutbox()[noteId];
  if (entry) writeOutboxEntry(noteId, { ...entry, create: false });
  queryClient?.invalidateQueries({ queryKey: ["tags"] });
  if (noteDraftsEqual(noteToDraft(created), draft))
    return { status: "saved", note: created };
  return saveNote(
    noteId,
    draftUpdate(draft, created.reminder ?? null, {
      isViewer: false,
      baseVersion: created.version,
    }),
  );
}

const saveQueues = new Map<
  string,
  { queue: NoteSaveQueue; live: { current: EditorLink } }
>();

/**
 * Writes what the queue still has to send into the outbox, or clears it.
 * Called after a save settles: until then the queue still counts the draft
 * as on its way.
 */
function keepLater(noteId: string) {
  window.setTimeout(() => keep(noteId), 0);
}

function keep(noteId: string) {
  const entry = saveQueues.get(noteId);
  if (!entry) return;
  const draft = entry.queue.newestDraft();
  const before = readOutbox()[noteId];
  if (!draft) {
    // A note made offline stays in the outbox until the server has it.
    if (before && !before.create) writeOutboxEntry(noteId, null);
    return;
  }
  writeOutboxEntry(noteId, {
    draft,
    base: entry.live.current.base() ?? before?.base ?? null,
    baseVersion: entry.queue.baseVersion(),
    create: before?.create,
  });
}

/** One save queue per note, kept across visits while it has text to send. */
export function noteSaveQueue(noteId: string) {
  let entry = saveQueues.get(noteId);
  if (!entry) {
    const live = { current: unlinkedEditor(noteId) };
    const queue = createNoteSaveQueue({
      save: (draft, baseVersion) =>
        readOutbox()[noteId]?.create
          ? createThenSave(noteId, draft)
          : saveNote(noteId, live.current.buildUpdate(draft, baseVersion)),
      onSaved: (draft, note) => {
        live.current.onSaved(draft, note);
        keepLater(noteId);
      },
      onConflict: (serverNote, draft, canRetry) => {
        const next = live.current.onConflict(serverNote, draft, canRetry);
        keepLater(noteId);
        return next;
      },
      onFailed: (failure) => {
        live.current.onFailed(failure);
        keepLater(noteId);
      },
      onBusyChange: (busy) => live.current.onBusyChange(busy),
    });
    const push = queue.push;
    queue.push = (draft) => {
      push(draft);
      keep(noteId);
      showDraft(noteId, draft);
    };
    entry = { queue, live };
    saveQueues.set(noteId, entry);
  }
  return entry;
}

export function savesSettled(noteId: string): Promise<void> {
  return saveQueues.get(noteId)?.queue.settled() ?? Promise.resolve();
}

export function releaseSaveQueue(noteId: string) {
  const entry = saveQueues.get(noteId);
  if (!entry) return;
  const link = entry.live.current;
  void entry.queue.settled().then(() => {
    if (saveQueues.get(noteId) !== entry || entry.live.current !== link) return;
    // Still unsent: the queue carries on without the editor.
    if (entry.queue.newestDraft()) entry.live.current = unlinkedEditor(noteId);
    else saveQueues.delete(noteId);
  });
}

/** Records a note made offline, before its first save reaches the server. */
export function keepNewNote(noteId: string, draft: NoteDraft | null) {
  const before = readOutbox()[noteId];
  if (!draft) {
    if (before?.create) writeOutboxEntry(noteId, null);
    return;
  }
  writeOutboxEntry(noteId, { draft, base: null, create: true });
}

/** A note made offline that the server doesn't have yet, as a card. */
export function localNote(
  noteId: string,
  entry: OutboxEntry,
  userId: string,
): Note {
  const now = new Date().toISOString();
  return {
    id: noteId,
    title: entry.draft.title,
    content: entry.draft.content,
    isPinned: entry.draft.isPinned,
    isArchived: false,
    background: entry.draft.background,
    tagIds: entry.draft.tagIds,
    reminder: entry.draft.reminder,
    state: "active",
    version: 0,
    createdAt: now,
    updatedAt: now,
    userId,
    permission: "owner",
  };
}

/**
 * Refills the save queues from the outbox, so edits made before a reload go
 * up once the server can be reached. Notes made offline join the lists.
 */
export function restoreOutbox(client: QueryClient, userId: string) {
  queryClient = client;
  for (const [noteId, entry] of Object.entries(readOutbox())) {
    if (entry.create) {
      const note = localNote(noteId, entry, userId);
      client.setQueryData(
        ["notes", noteId],
        (old: Note | undefined) => old ?? note,
      );
      client.setQueriesData<unknown>(
        { queryKey: ["notes"] },
        (data: unknown) =>
          Array.isArray(data) && !(data as Note[]).some((n) => n.id === noteId)
            ? [note, ...data]
            : data,
      );
    }
    const { queue } = noteSaveQueue(noteId);
    if (queue.newestDraft()) continue;
    queue.setBaseVersion(entry.baseVersion);
    queue.push(entry.draft);
  }
}

if (typeof window !== "undefined")
  window.addEventListener("online", () => {
    for (const { queue } of saveQueues.values()) queue.retryNow();
  });
