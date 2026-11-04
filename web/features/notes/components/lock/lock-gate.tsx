"use client";

import { Archive, ArrowLeft, Lock } from "lucide-react";
import { IconButton } from "@/components/ui/button";
import { Tip } from "@/components/ui/tooltip";
import { hasTitle } from "../../title";
import type { Note, NoteLockKind } from "../../types";
import { UnlockForm } from "./unlock-form";

/**
 * Stands in for a locked note until it is unlocked this session. It can
 * still go to the archive without being unlocked.
 */
export function LockGate({
  note,
  onBack,
  onArchive,
}: {
  note: Pick<Note, "id" | "title" | "background"> & { lock: NoteLockKind };
  onBack: () => void;
  /** Absent where the note can't be archived (already is, or trashed). */
  onArchive?: () => void;
}) {
  const title = hasTitle(note.title) ? note.title : "Untitled";
  return (
    <div className="pg-editor">
      <article
        className="note ed"
        data-note={note.background ?? ""}
        aria-label="Locked note"
      >
        <div className="ed-scroll scrollbar-slim">
          <div className="ed-head">
            <div className="ed-head-l">
              <Tip label="Back">
                <IconButton label="Back" onClick={onBack}>
                  <ArrowLeft />
                </IconButton>
              </Tip>
            </div>
            {onArchive && (
              <div className="ed-head-r">
                <Tip label="Archive">
                  <IconButton label="Archive" onClick={onArchive}>
                    <Archive />
                  </IconButton>
                </Tip>
              </div>
            )}
          </div>
          <div className="lock-gate">
            <span className="lock-gate-icon" aria-hidden>
              <Lock />
            </span>
            <h1>{title}</h1>
            <p className="m-0 text-muted-foreground text-ui">
              This note is locked.
            </p>
            <UnlockForm noteId={note.id} kind={note.lock} />
          </div>
        </div>
      </article>
    </div>
  );
}
