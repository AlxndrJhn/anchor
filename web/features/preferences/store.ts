import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Shortcut } from "@/features/notes/date-stamp";

export type ViewMode = "masonry" | "grid" | "list";
export type SortBy = "updatedAt" | "createdAt" | "title";
export type SortOrder = "asc" | "desc";

export type AppStyle = "default" | "skeuomorphism" | "neo-brutalism" | "lofi";

interface UIPreferences {
  sidebarCollapsed: boolean;
  /** A colour scheme id from lib/design/schemes, or "anchor". */
  colorScheme?: string;
  style?: AppStyle;
}

interface NotesPreferences {
  viewMode: ViewMode;
  sortBy: SortBy;
  sortOrder: SortOrder;
  /** Pictures across the top of note cards. Unset (older saves) means on. */
  showPictures?: boolean;
}

interface EditorPreferences {
  sortChecklistItems: boolean;
  /** Deleted notes burn away. Unset (older saves) means on. */
  burnDeleted?: boolean;
  /** Inserts today's date; unset means the default (Ctrl+;). */
  dateShortcut?: Shortcut;
  /** Inserts the date and time; unset means Ctrl+Shift+;. */
  dateTimeShortcut?: Shortcut;
}

interface PreferencesState {
  ui: UIPreferences;
  notes: NotesPreferences;
  editor: EditorPreferences;
  setUIPreference: <K extends keyof UIPreferences>(
    key: K,
    value: UIPreferences[K],
  ) => void;
  setNotesPreference: <K extends keyof NotesPreferences>(
    key: K,
    value: NotesPreferences[K],
  ) => void;
  setEditorPreference: <K extends keyof EditorPreferences>(
    key: K,
    value: EditorPreferences[K],
  ) => void;
}

const defaultUIPreferences: UIPreferences = {
  sidebarCollapsed: false,
};

const defaultNotesPreferences: NotesPreferences = {
  viewMode: "masonry",
  sortBy: "updatedAt",
  sortOrder: "desc",
  showPictures: true,
};

const defaultEditorPreferences: EditorPreferences = {
  sortChecklistItems: true,
  burnDeleted: true,
};

const initialState = {
  ui: defaultUIPreferences,
  notes: defaultNotesPreferences,
  editor: defaultEditorPreferences,
};

export const usePreferencesStore = create<PreferencesState>()(
  persist(
    (set) => ({
      ...initialState,
      setUIPreference: (key, value) =>
        set((state) => ({
          ui: { ...state.ui, [key]: value },
        })),
      setNotesPreference: (key, value) =>
        set((state) => ({
          notes: { ...state.notes, [key]: value },
        })),
      setEditorPreference: (key, value) =>
        set((state) => ({
          editor: { ...state.editor, [key]: value },
        })),
    }),
    {
      name: "preferences",
    },
  ),
);
