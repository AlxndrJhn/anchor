"use client";

import * as React from "react";
import { usePreferencesStore } from "@/features/preferences";

/**
 * Something on screen that an Esc or a letter key belongs to first; not one
 * already on its way out.
 */
const OVERLAYS = [
  '[role="dialog"]',
  '[role="alertdialog"]',
  '[role="menu"]',
  '[role="listbox"]',
]
  .map((role) => `${role}:not([data-state="closed"])`)
  .concat(".hl-bubble")
  .join(", ");

export function isTypingTarget(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) return false;
  return (
    target.isContentEditable ||
    target.closest("input, textarea, select, [contenteditable=true]") !== null
  );
}

export function hasOverlay() {
  return document.querySelector(OVERLAYS) !== null;
}

/**
 * Whether a letter, digit or symbol key alone may act; Settings can turn
 * these off (WCAG 2.1.4). Keys like Esc always may.
 */
export function singleKeyAllowed(key: string) {
  return (
    key.length !== 1 ||
    usePreferencesStore.getState().editor.singleKeyShortcuts !== false
  );
}

/**
 * Single-key shortcuts like Google Keep's. `keys` maps `e.key` to an action;
 * they never fire while typing, with a modifier held, under an overlay, or,
 * for character keys, with single-key shortcuts turned off in Settings.
 */
export function useShortcuts(
  keys: Record<string, (e: KeyboardEvent) => void>,
  enabled = true,
) {
  const live = React.useRef(keys);
  live.current = keys;
  React.useEffect(() => {
    if (!enabled) return;
    // The overlay is checked before its own Esc handler can close it.
    let overlayAtPress = false;
    const capture = () => {
      overlayAtPress = hasOverlay();
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.defaultPrevented || e.isComposing || overlayAtPress) return;
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      if (isTypingTarget(e.target)) return;
      if (!singleKeyAllowed(e.key)) return;
      const run = live.current[e.key];
      if (!run) return;
      e.preventDefault();
      run(e);
    };
    window.addEventListener("keydown", capture, true);
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("keydown", capture, true);
      window.removeEventListener("keydown", onKey);
    };
  }, [enabled]);
}
