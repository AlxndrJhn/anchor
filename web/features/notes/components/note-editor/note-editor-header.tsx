"use client";

import {
  Archive,
  ArchiveRestore,
  ArrowLeft,
  Bell,
  BellRing,
  Check,
  CircleAlert,
  CloudOff,
  Copy,
  Ellipsis,
  History,
  List,
  ListChecks,
  ListRestart,
  ListX,
  LoaderCircle,
  Lock,
  LockOpen,
  LogOut,
  Palette,
  Pin,
  PinOff,
  Send,
  Snowflake,
  Trash2,
  UserPlus,
} from "lucide-react";
import * as React from "react";
import { IconButton } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Tip } from "@/components/ui/tooltip";
import { useSyncStatus } from "@/features/sync";
import { useRovingFocus } from "@/lib/hooks/use-roving-focus";
import { cn } from "@/lib/utils";
import { isReminderPast, reminderLabel } from "../../reminder";
import type {
  NoteLockKind,
  NoteReminder,
  ReminderRecurrence,
} from "../../types";
import { BackgroundPicker } from "../background-picker";
import { ReminderPopoverContent } from "../reminder-picker";

export type SaveState = "new" | "saving" | "saved" | "offline" | "failed";

interface NoteEditorHeaderProps {
  saveState: SaveState;
  onRetrySave: () => void;
  onBack: () => void;
  trashed?: boolean;
  readOnly?: boolean;
  canSetReminder: boolean;
  saved: boolean;
  isOwner: boolean;
  canViewHistory: boolean;
  isPinned: boolean;
  isArchived: boolean;
  background: string | null;
  reminder: NoteReminder | null;
  sharedWithCount: number;
  onTogglePin: () => void;
  onBackground: (background: string | null) => void;
  onPreviewBackground: (background: string | null | false) => void;
  onReminder: (
    reminder: { remindAt: string; recurrence: ReminderRecurrence } | null,
  ) => void;
  onShare: () => void;
  onHistory: () => void;
  /** How the note is locked for this person, if it is. */
  lock: NoteLockKind | null;
  /** Opens the lock choices (Lock… or Change lock…). */
  onLock: () => void;
  onRemoveLock: () => void;
  /** Frozen: it can't be changed, trashed or deleted. */
  frozen: boolean;
  /** Freezes or unfreezes it; absent for those who don't own it. */
  onToggleFreeze?: () => void;
  /** Hands the note to another app (or copies it as text). */
  onSend: () => void;
  /** Makes a copy of the note; absent for a note not yet saved. */
  onCopy?: () => void;
  onArchive: () => void;
  onUnarchive: () => void;
  onTrash: () => void;
  /** Google Keep's "Show checkboxes" or "Hide checkboxes", whichever fits. */
  checkboxes: "show" | "hide" | null;
  onCheckboxes: () => void;
  /** Ticked checklist items in the note. */
  checkedCount: number;
  onUncheckAll: () => void;
  onRemoveChecked: () => void;
}

export function NoteEditorHeader(props: NoteEditorHeaderProps) {
  const [reminderOpen, setReminderOpen] = React.useState(false);
  const roving = useRovingFocus<HTMLDivElement>();
  const [startedUnsaved] = React.useState(!props.saved);
  const afterSave = startedUnsaved && "after-save";
  // Runs once the menu has closed and let go of focus.
  const afterMenu = React.useRef<(() => void) | null>(null);
  const late = !!props.reminder && isReminderPast(props.reminder);
  const checkboxesLabel =
    props.checkboxes === "show" ? "Show checkboxes" : "Hide checkboxes";
  const trashLabel = props.isOwner ? "Move to trash" : "Remove from my notes";
  const bellLabel = props.reminder
    ? `${late ? "Late reminder" : "Reminder"}: ${reminderLabel(props.reminder)}`
    : "Add a reminder";

  return (
    <div
      ref={roving.ref}
      className="ed-head"
      role="toolbar"
      aria-label="Note"
      onFocus={roving.onFocus}
      onKeyDown={roving.onKeyDown}
    >
      <div className="ed-head-l">
        <Tip label="Back">
          <IconButton label="Back" onClick={props.onBack}>
            <ArrowLeft />
          </IconButton>
        </Tip>
        <SaveStatus state={props.saveState} onRetry={props.onRetrySave} />
      </div>
      {props.trashed && props.canViewHistory && (
        <div className="ed-head-r">
          <Tip label="Version history">
            <IconButton label="Version history" onClick={props.onHistory}>
              <History />
            </IconButton>
          </Tip>
        </div>
      )}
      {!props.trashed && (
        <div className="ed-head-r">
          {!props.readOnly && (
            <Popover
              onOpenChange={(open) => !open && props.onPreviewBackground(false)}
            >
              <Tip label="Background">
                <PopoverTrigger asChild>
                  <IconButton label="Background">
                    <Palette />
                  </IconButton>
                </PopoverTrigger>
              </Tip>
              <PopoverContent align="end" className="p-0">
                <BackgroundPicker
                  value={props.background}
                  onChange={props.onBackground}
                  onPreview={props.onPreviewBackground}
                />
              </PopoverContent>
            </Popover>
          )}
          {props.canSetReminder && (
            <Popover open={reminderOpen} onOpenChange={setReminderOpen}>
              <Tip label={bellLabel}>
                <PopoverTrigger asChild>
                  <IconButton
                    label={bellLabel}
                    className={cn(
                      props.reminder &&
                        (late ? "text-late" : "text-accent-strong"),
                    )}
                  >
                    {late ? <BellRing /> : <Bell />}
                  </IconButton>
                </PopoverTrigger>
              </Tip>
              <ReminderPopoverContent
                align="end"
                reminder={props.reminder}
                onReminder={props.onReminder}
                onClose={() => setReminderOpen(false)}
              />
            </Popover>
          )}
          {props.saved && (
            <Tip label={props.isPinned ? "Unpin" : "Pin"}>
              <IconButton
                label={props.isPinned ? "Unpin" : "Pin"}
                aria-pressed={props.isPinned}
                onClick={props.onTogglePin}
                className={cn(
                  "max-md:hidden aria-pressed:[&_svg]:fill-current",
                  afterSave,
                )}
              >
                <Pin />
              </IconButton>
            </Tip>
          )}
          {/* On wide screens these sit in the bar; narrow, in the menu. */}
          {!props.readOnly && props.checkboxes && (
            <Tip label={checkboxesLabel}>
              <IconButton
                label={checkboxesLabel}
                onClick={props.onCheckboxes}
                className="max-md:hidden"
              >
                {props.checkboxes === "show" ? <ListChecks /> : <List />}
              </IconButton>
            </Tip>
          )}
          {props.saved && (
            <Tip label={props.isArchived ? "Unarchive" : "Archive"}>
              <IconButton
                label={props.isArchived ? "Unarchive" : "Archive"}
                onClick={props.isArchived ? props.onUnarchive : props.onArchive}
                className={cn("max-md:hidden", afterSave)}
              >
                {props.isArchived ? <ArchiveRestore /> : <Archive />}
              </IconButton>
            </Tip>
          )}
          {props.saved && !(props.frozen && props.isOwner) && (
            <Tip label={trashLabel}>
              <IconButton
                label={trashLabel}
                onClick={props.onTrash}
                className={cn("max-md:hidden", afterSave)}
              >
                {props.isOwner ? <Trash2 /> : <LogOut />}
              </IconButton>
            </Tip>
          )}
          {props.saved && (
            <DropdownMenu>
              <Tip label="More">
                <DropdownMenuTrigger asChild>
                  <IconButton label="More" className={cn(afterSave)}>
                    <Ellipsis />
                  </IconButton>
                </DropdownMenuTrigger>
              </Tip>
              <DropdownMenuContent
                align="end"
                className="min-w-55"
                onCloseAutoFocus={(e) => {
                  const next = afterMenu.current;
                  if (!next) return;
                  afterMenu.current = null;
                  e.preventDefault();
                  next();
                }}
              >
                <div className="contents md:hidden">
                  <DropdownMenuItem onSelect={props.onTogglePin}>
                    {props.isPinned ? <PinOff /> : <Pin />}
                    {props.isPinned ? "Unpin" : "Pin"}
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                </div>
                {props.isOwner && (
                  <DropdownMenuItem onSelect={props.onShare}>
                    <UserPlus />
                    {props.sharedWithCount ? "Sharing" : "Share"}
                  </DropdownMenuItem>
                )}
                {!props.readOnly && props.checkboxes && (
                  <div className="contents md:hidden">
                    <DropdownMenuItem onSelect={props.onCheckboxes}>
                      {props.checkboxes === "show" ? <ListChecks /> : <List />}
                      {checkboxesLabel}
                    </DropdownMenuItem>
                  </div>
                )}
                {!props.readOnly && props.checkedCount > 0 && (
                  <>
                    <DropdownMenuItem onSelect={props.onUncheckAll}>
                      <ListRestart />
                      Untick all items
                    </DropdownMenuItem>
                    <DropdownMenuItem onSelect={props.onRemoveChecked}>
                      <ListX />
                      Delete ticked items
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                  </>
                )}
                <DropdownMenuItem
                  onSelect={() => {
                    afterMenu.current = props.onSend;
                  }}
                >
                  <Send />
                  Send
                </DropdownMenuItem>
                {props.onCopy && (
                  <DropdownMenuItem onSelect={props.onCopy}>
                    <Copy />
                    Make a copy
                  </DropdownMenuItem>
                )}
                {props.canViewHistory && (
                  <DropdownMenuItem
                    onSelect={() => {
                      afterMenu.current = props.onHistory;
                    }}
                  >
                    <History />
                    Version history
                  </DropdownMenuItem>
                )}
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  onSelect={() => {
                    afterMenu.current = props.onLock;
                  }}
                >
                  <Lock />
                  {props.lock ? "Change lock…" : "Lock…"}
                </DropdownMenuItem>
                {props.lock && (
                  <DropdownMenuItem onSelect={props.onRemoveLock}>
                    <LockOpen />
                    Remove lock
                  </DropdownMenuItem>
                )}
                {props.onToggleFreeze && (
                  <DropdownMenuItem onSelect={props.onToggleFreeze}>
                    <Snowflake />
                    {props.frozen ? "Unfreeze" : "Freeze"}
                  </DropdownMenuItem>
                )}
                <div className="contents md:hidden">
                  {props.isArchived ? (
                    <DropdownMenuItem onSelect={props.onUnarchive}>
                      <ArchiveRestore />
                      Unarchive
                    </DropdownMenuItem>
                  ) : (
                    <DropdownMenuItem onSelect={props.onArchive}>
                      <Archive />
                      Archive
                    </DropdownMenuItem>
                  )}
                  {!(props.frozen && props.isOwner) && (
                    <>
                      <DropdownMenuSeparator />
                      <DropdownMenuItem tone="danger" onSelect={props.onTrash}>
                        {props.isOwner ? <Trash2 /> : <LogOut />}
                        {trashLabel}
                      </DropdownMenuItem>
                    </>
                  )}
                </div>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
      )}
    </div>
  );
}

function SaveStatus({
  state,
  onRetry,
}: {
  state: SaveState;
  onRetry: () => void;
}) {
  const online = useSyncStatus((s) => s.online);
  if (state === "new") return null;
  const labelClass = "max-md:sr-only";
  const waitingHint = online
    ? "The server isn’t answering. Keep this tab open so your changes can be saved."
    : "You’re offline. Your changes are kept on this device and saved when you’re back online.";
  return (
    <span className="save" aria-live="polite">
      {state === "saved" && (
        <span data-s>
          <Check aria-hidden />
          <span className={labelClass}>Saved</span>
        </span>
      )}
      {state === "saving" && (
        <span data-s>
          <LoaderCircle aria-hidden className="animate-spin" />
          <span className={labelClass}>Saving…</span>
        </span>
      )}
      {state === "offline" && (
        <Tip label={waitingHint}>
          <span data-s>
            <CloudOff aria-hidden />
            <span className={labelClass}>Waiting to save</span>
            <span className="sr-only">. {waitingHint}</span>
          </span>
        </Tip>
      )}
      {state === "failed" && (
        <span data-s className="font-medium text-late">
          <CircleAlert aria-hidden />
          <span className={labelClass}>Couldn’t save</span>
          <button
            type="button"
            onClick={onRetry}
            className="ml-0.5 cursor-pointer border-0 bg-transparent p-0 font-semibold text-inherit underline decoration-current/35 underline-offset-3 hover:decoration-current"
          >
            Try again
          </button>
        </span>
      )}
    </span>
  );
}
