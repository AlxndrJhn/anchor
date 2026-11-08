import type { NoteSharePermission } from "./types";

/** Says what a note's public link lets anyone who has it do. */
export const publicLinkLabel = (permission: NoteSharePermission) =>
  permission === "editor"
    ? "Public: anyone with the link can edit"
    : "Public: anyone with the link can view";
