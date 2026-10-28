"use client";

import {
  Archive,
  ArchiveRestore,
  CloudOff,
  Lock,
  RotateCcw,
  Snowflake,
  Trash2,
} from "lucide-react";
import * as React from "react";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { useRovingFocus } from "@/lib/hooks/use-roving-focus";
import { cn } from "@/lib/utils";
import type { Person } from "./note-editor-content";

type ReadOnlyBarProps =
  | {
      kind: "trash";
      deletesOn: Date;
      onRestore: () => void;
      onDelete: () => void;
      restoring?: boolean;
    }
  | { kind: "view"; sharedBy: Person }
  | { kind: "archived"; onUnarchive: () => void }
  | { kind: "frozen"; onUnfreeze?: () => void }
  | { kind: "refused" }
  | { kind: "offline" };

/** A new `nudge` number shakes it. */
export function ReadOnlyBar(props: ReadOnlyBarProps & { nudge?: number }) {
  const ref = React.useRef<HTMLDivElement>(null);
  const actions = useRovingFocus<HTMLSpanElement>();
  React.useEffect(() => {
    const el = ref.current;
    if (!props.nudge || !el) return;
    el.classList.remove("nudge", "flash");
    void el.offsetWidth;
    el.classList.add("nudge", "flash");
    const timer = window.setTimeout(() => el.classList.remove("flash"), 700);
    return () => window.clearTimeout(timer);
  }, [props.nudge]);

  const icon = (node: React.ReactNode) => (
    <span className="ic" aria-hidden>
      {node}
    </span>
  );
  return (
    <div
      ref={ref}
      role="status"
      className={cn("ro-bar")}
      onAnimationEnd={() => ref.current?.classList.remove("nudge")}
    >
      {props.kind === "trash" && (
        <>
          {icon(<Trash2 />)}
          <span className="ro-msg">
            <b>In trash.</b> It will be deleted on{" "}
            {props.deletesOn.toLocaleDateString(undefined, {
              month: "short",
              day: "numeric",
            })}
            .
          </span>
          <span
            ref={actions.ref}
            className="ro-acts"
            role="toolbar"
            aria-label="In trash"
            onFocus={actions.onFocus}
            onKeyDown={actions.onKeyDown}
          >
            <Button
              onClick={props.onRestore}
              busy={props.restoring && "Restoring…"}
            >
              <RotateCcw aria-hidden />
              Restore
            </Button>
            <Button variant="danger" onClick={props.onDelete}>
              Delete permanently
            </Button>
          </span>
        </>
      )}
      {props.kind === "view" && (
        <>
          <Avatar
            id={props.sharedBy.id}
            name={props.sharedBy.name}
            src={props.sharedBy.profileImage}
            size="md"
          />
          <span className="ro-msg">
            <b>View only.</b> Shared by {props.sharedBy.name.split(" ")[0]}.
          </span>
        </>
      )}
      {props.kind === "archived" && (
        <>
          {icon(<Archive />)}
          <span className="ro-msg">
            <b>Archived.</b> It’s hidden from your notes list.
          </span>
          <span className="ro-acts">
            <Button variant="quiet" onClick={props.onUnarchive}>
              <ArchiveRestore aria-hidden />
              Unarchive
            </Button>
          </span>
        </>
      )}
      {props.kind === "offline" && (
        <>
          {icon(<CloudOff />)}
          <span className="ro-msg">
            <b>You’re offline.</b> Your changes are kept on this device and sync
            when you’re back online.
          </span>
        </>
      )}
      {props.kind === "frozen" && (
        <>
          {icon(<Snowflake />)}
          <span className="ro-msg">
            <b>Frozen.</b> It can’t be changed or deleted
            {props.onUnfreeze ? " until you unfreeze it" : ""}.
          </span>
          {props.onUnfreeze && (
            <span className="ro-acts">
              <Button variant="quiet" onClick={props.onUnfreeze}>
                <Snowflake aria-hidden />
                Unfreeze
              </Button>
            </span>
          )}
        </>
      )}
      {props.kind === "refused" && (
        <>
          {icon(<Lock />)}
          <span className="ro-msg">
            <b>You can no longer edit this note.</b>
          </span>
        </>
      )}
    </div>
  );
}
