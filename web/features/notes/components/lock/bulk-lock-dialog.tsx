"use client";

import { toast } from "@/components/ui/toast";
import { plural } from "@/lib/utils";
import { useApplyLock, useUnlockedIds } from "../../hooks/use-note-lock";
import { lockableNotes } from "../../note-lock";
import type { Note } from "../../types";
import { LockDialog } from "./lock-dialog";

/**
 * Lock… for the notes picked. Notes still locked this session stay as they
 * are: a lock can only be changed once its note has been opened.
 */
export function BulkLockDialog({
  notes,
  open,
  onOpenChange,
  onDone,
}: {
  notes: Note[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onDone: () => void;
}) {
  const applyLock = useApplyLock();
  const unlocked = useUnlockedIds();
  const { lockable, skipped } = lockableNotes(notes, unlocked);
  const kinds = new Set(lockable.map((n) => n.lock ?? null));
  const current = kinds.size === 1 ? [...kinds][0] : null;
  return (
    <LockDialog
      open={open}
      onOpenChange={onOpenChange}
      count={lockable.length || notes.length}
      current={current}
      onLock={async (kind) => {
        if (!lockable.length) {
          toast.info(
            `${notes.length === 1 ? "That note is" : "Those notes are"} locked. Open ${notes.length === 1 ? "it" : "them"} to change the lock.`,
          );
          return;
        }
        await applyLock(lockable, kind);
        onDone();
        const locked = `${plural(lockable.length, "note")} locked`;
        toast.success(
          skipped.length
            ? `${locked}. ${plural(skipped.length, "locked note")} left as ${skipped.length === 1 ? "it was" : "they were"}: open ${skipped.length === 1 ? "it" : "them"} to change ${skipped.length === 1 ? "its" : "their"} lock.`
            : locked,
        );
      }}
    />
  );
}
