"use client";

import {
  type QueryClient,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import * as React from "react";
import { useAuthStore } from "@/features/auth/store";
import {
  bulkLockNotes,
  getNoteLockSecrets,
  setNoteLock,
  verifyNoteLock,
} from "../api";
import {
  lockSecretMatches,
  type UnlockMethod,
  useUnlockedNotes,
} from "../note-lock";
import type { Note, NoteLockKind, NoteLockSecrets } from "../types";

export const NOTE_LOCKS_KEY = ["note-locks"] as const;

/** This person's PIN and pattern hashes, kept on the device for offline. */
export function useNoteLockSecrets() {
  return useQuery({
    queryKey: NOTE_LOCKS_KEY,
    queryFn: getNoteLockSecrets,
    staleTime: 60_000,
  });
}

/** The notes unlocked this session, as a set that changes when they do. */
export const useUnlockedIds = () => useUnlockedNotes((s) => s.ids);

/**
 * Whether `secret` opens a note locked with `method`. A PIN or pattern is
 * checked here against its hash when this browser can; the password, and
 * anything this browser can't check, by the server. Throws when that can't
 * be reached.
 */
export async function checkUnlock(
  method: Exclude<UnlockMethod, "tap">,
  secret: string,
  secrets: NoteLockSecrets | undefined,
): Promise<boolean> {
  if (method !== "password") {
    const stored = secrets?.[method];
    if (stored) {
      const matches = await lockSecretMatches(secret, stored);
      if (matches !== null) return matches;
    }
  }
  return verifyNoteLock(method, secret);
}

/** Sets `lock` on the notes wherever they are cached (lists and opened). */
export function patchCachedLock(
  queryClient: QueryClient,
  ids: string[],
  lock: NoteLockKind | null,
) {
  const wanted = new Set(ids);
  const patch = (n: Note) => (wanted.has(n.id) ? { ...n, lock } : n);
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
 * Locks, relocks or unlocks notes for this person: the cards change at once,
 * and go back if the server turns it down. Needs a connection.
 */
export function useApplyLock() {
  const queryClient = useQueryClient();
  return React.useCallback(
    async (
      notes: Pick<Note, "id" | "lock">[],
      lock: NoteLockKind | null,
    ): Promise<void> => {
      const ids = notes.map((n) => n.id);
      if (!ids.length) return;
      patchCachedLock(queryClient, ids, lock);
      try {
        if (ids.length === 1) await setNoteLock(ids[0], lock);
        else await bulkLockNotes(ids, lock);
      } catch (error) {
        for (const note of notes)
          patchCachedLock(queryClient, [note.id], note.lock ?? null);
        throw error;
      } finally {
        void queryClient.invalidateQueries({ queryKey: ["notes"] });
      }
    },
    [queryClient],
  );
}

/**
 * Ends the unlock session when another person signs in here, and when the
 * desktop app says the computer's screen was locked.
 */
export function useLockSession() {
  const userId = useAuthStore((s) => s.user?.id ?? null);
  const lastUser = React.useRef(userId);
  React.useEffect(() => {
    if (lastUser.current === userId) return;
    lastUser.current = userId;
    useUnlockedNotes.getState().endSession();
  }, [userId]);
  React.useEffect(() => {
    const end = () => useUnlockedNotes.getState().endSession();
    window.addEventListener("anchor:screen-locked", end);
    return () => window.removeEventListener("anchor:screen-locked", end);
  }, []);
}
