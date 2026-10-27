import type { QueryClient, QueryKey } from "@tanstack/react-query";
import { idbClear, idbDelete, idbEntries, idbGet, idbSet } from "./idb";

// Keeps the notes lists, the notes opened, the tags and the note-lock hashes
// on the device, so the app shows them (and opens locked notes) after a
// reload without a connection.

const PREFIX = "query:";
const OWNER_KEY = "owner";
const KEPT_ROOTS = new Set(["notes", "tags", "note-locks"]);

interface StoredQuery {
  key: QueryKey;
  data: unknown;
  updatedAt: number;
}

const isKept = (key: QueryKey) => KEPT_ROOTS.has(String(key[0]));

/**
 * Restores the stored queries for `userId` into `queryClient` (anything
 * already loaded wins), then keeps the store up to date. Returns a cleanup.
 */
export async function persistQueries(
  queryClient: QueryClient,
  userId: string,
): Promise<() => void> {
  // Another person's notes never show.
  if ((await idbGet<string>(OWNER_KEY)) !== userId) {
    await idbClear();
    await idbSet(OWNER_KEY, userId);
  }

  for (const [name, stored] of await idbEntries<StoredQuery>()) {
    if (!name.startsWith(PREFIX) || !stored?.key) continue;
    if (queryClient.getQueryData(stored.key) !== undefined) continue;
    queryClient.setQueryData(stored.key, stored.data, {
      updatedAt: stored.updatedAt,
    });
  }

  const timers = new Map<string, number>();
  const unsubscribe = queryClient.getQueryCache().subscribe((event) => {
    const { query } = event;
    if (!isKept(query.queryKey)) return;
    const name = PREFIX + query.queryHash;
    if (event.type === "removed") {
      void idbDelete(name);
      return;
    }
    if (event.type !== "updated" || query.state.data === undefined) return;
    // Typing saves often; write each query at most every half second.
    window.clearTimeout(timers.get(name));
    timers.set(
      name,
      window.setTimeout(() => {
        timers.delete(name);
        void idbSet(name, {
          key: query.queryKey,
          data: query.state.data,
          updatedAt: query.state.dataUpdatedAt,
        } satisfies StoredQuery);
      }, 500),
    );
  });

  return () => {
    unsubscribe();
    for (const timer of timers.values()) window.clearTimeout(timer);
  };
}

/** Forgets everything kept on the device (signing out). */
export const forgetStoredQueries = () => idbClear();
