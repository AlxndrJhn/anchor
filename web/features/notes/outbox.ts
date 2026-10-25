import { useAuthStore } from "@/features/auth/store";
import type { NoteDraft } from "./save-queue";

// Edits not yet on the server, kept on the device so they survive a reload or
// a closed tab while offline. The save queues write it; on start-up they are
// refilled from it and send what they hold once the server can be reached.

export interface OutboxEntry {
  draft: NoteDraft;
  /** The server's copy the draft was made from, to merge onto a newer one. */
  base: NoteDraft | null;
  baseVersion?: number;
  /** A note made offline that the server has not seen yet. */
  create?: boolean;
}

type Outbox = Record<string, OutboxEntry>;

function storageKey() {
  const userId = useAuthStore.getState().user?.id;
  return userId ? `anchor-outbox:${userId}` : null;
}

export function readOutbox(): Outbox {
  const key = storageKey();
  if (!key || typeof localStorage === "undefined") return {};
  try {
    return JSON.parse(localStorage.getItem(key) ?? "{}") as Outbox;
  } catch {
    return {};
  }
}

export function outboxEntry(noteId: string): OutboxEntry | undefined {
  return readOutbox()[noteId];
}

export function writeOutboxEntry(noteId: string, entry: OutboxEntry | null) {
  const key = storageKey();
  if (!key) return;
  const outbox = readOutbox();
  if (entry) outbox[noteId] = entry;
  else if (noteId in outbox) delete outbox[noteId];
  else return;
  try {
    if (Object.keys(outbox).length)
      localStorage.setItem(key, JSON.stringify(outbox));
    else localStorage.removeItem(key);
  } catch {
    // Storage full or blocked: the edit still goes up while the tab is open.
  }
}
