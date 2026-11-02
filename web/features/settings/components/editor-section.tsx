"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { SegmentedControl } from "@/components/ui/segmented-control";
import { Switch } from "@/components/ui/switch";
import {
  type DateFormat,
  DEFAULT_DATE_FORMAT,
  DEFAULT_DATE_SHORTCUT,
  DEFAULT_DATE_TIME_SHORTCUT,
  formatDate,
  type Shortcut,
  shortcutFromEvent,
} from "@/features/notes/date-stamp";
import { type NoteLayout, usePreferencesStore } from "@/features/preferences";
import {
  Row,
  RowText,
  SaveStatus,
  Section,
  useSaveStatus,
} from "./settings-blocks";

export function EditorSection() {
  const { editor, setEditorPreference } = usePreferencesStore();
  const [saveStatus, setSaveStatus] = useSaveStatus();
  const today = new Date();
  return (
    <Section id="editor" title="Editor">
      <Row>
        <RowText
          title="Note layout"
          text="Clean puts tags under the text and folds the formatting bar away until you open it."
        />
        <SegmentedControl<NoteLayout>
          aria-label="Note layout"
          size="sm"
          value={editor.noteLayout ?? "default"}
          onValueChange={(layout) => {
            setEditorPreference("noteLayout", layout);
            setSaveStatus("saved");
          }}
          options={[
            { value: "default", label: "Default" },
            { value: "clean", label: "Clean" },
          ]}
        />
      </Row>
      <Row>
        <RowText
          title={
            <label htmlFor="sort-checked">
              Move checked items to the bottom
            </label>
          }
          text="Checked items move below the unchecked ones."
          saved={<SaveStatus state={saveStatus} />}
        />
        <Switch
          id="sort-checked"
          checked={editor.sortChecklistItems}
          onCheckedChange={(on) => {
            setEditorPreference("sortChecklistItems", on);
            setSaveStatus("saved");
          }}
        />
      </Row>
      <Row>
        <RowText
          title={<label htmlFor="burn-deleted">Burn deleted notes</label>}
          text="A deleted note burns away where it stood. Off, it just goes. On this device only."
        />
        <Switch
          id="burn-deleted"
          checked={editor.burnDeleted !== false}
          onCheckedChange={(on) => {
            setEditorPreference("burnDeleted", on);
            setSaveStatus("saved");
          }}
        />
      </Row>
      <Row>
        <RowText
          title="Insert today’s date"
          text={`In a note, types the date, e.g. ${formatDate(today, editor.dateFormat)}. Typing /date does the same.`}
        />
        <ShortcutRecorder
          id="date-shortcut"
          value={editor.dateShortcut ?? DEFAULT_DATE_SHORTCUT}
          isDefault={!editor.dateShortcut}
          onChange={(shortcut) => {
            setEditorPreference("dateShortcut", shortcut);
            setSaveStatus("saved");
          }}
        />
      </Row>
      <Row>
        <RowText title="Date format" text="How an inserted date reads." />
        <SegmentedControl<DateFormat>
          aria-label="Date format"
          size="sm"
          value={editor.dateFormat ?? DEFAULT_DATE_FORMAT}
          onValueChange={(format) => {
            setEditorPreference("dateFormat", format);
            setSaveStatus("saved");
          }}
          options={[
            { value: "long", label: formatDate(today, "long") },
            { value: "iso", label: formatDate(today, "iso") },
          ]}
        />
      </Row>
      <Row>
        <RowText
          title="Insert the date and time"
          text="In a note, types the time with its offset from UTC, e.g. 2026-10-27T11:23:49+01:00."
        />
        <ShortcutRecorder
          id="date-time-shortcut"
          value={editor.dateTimeShortcut ?? DEFAULT_DATE_TIME_SHORTCUT}
          isDefault={!editor.dateTimeShortcut}
          onChange={(shortcut) => {
            setEditorPreference("dateTimeShortcut", shortcut);
            setSaveStatus("saved");
          }}
        />
      </Row>
    </Section>
  );
}

/**
 * Shows a shortcut; clicked, it records the next key combination pressed
 * (Esc cancels). Reset brings back the default.
 */
function ShortcutRecorder({
  id,
  value,
  isDefault,
  onChange,
}: {
  id: string;
  value: Shortcut;
  isDefault: boolean;
  onChange: (shortcut: Shortcut | undefined) => void;
}) {
  const [recording, setRecording] = React.useState(false);
  return (
    <div className="flex shrink-0 items-center gap-1.5">
      <Button
        id={id}
        variant="secondary"
        size="sm"
        aria-label={
          recording
            ? "Press the new shortcut"
            : `Shortcut ${value.label}, change`
        }
        onClick={() => setRecording(true)}
        onBlur={() => setRecording(false)}
        onKeyDown={(e) => {
          if (!recording) return;
          e.preventDefault();
          e.stopPropagation();
          if (e.key === "Escape") {
            setRecording(false);
            return;
          }
          const shortcut = shortcutFromEvent(e.nativeEvent);
          if (!shortcut) return;
          onChange(shortcut);
          setRecording(false);
        }}
      >
        <kbd className="font-sans">
          {recording ? "Press keys…" : value.label}
        </kbd>
      </Button>
      {!isDefault && !recording && (
        <Button variant="quiet" size="sm" onClick={() => onChange(undefined)}>
          Reset
        </Button>
      )}
    </div>
  );
}
