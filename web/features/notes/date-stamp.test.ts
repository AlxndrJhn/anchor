import { describe, expect, it } from "vitest";
import {
  DEFAULT_DATE_SHORTCUT,
  DEFAULT_DATE_TIME_SHORTCUT,
  formatDate,
  formatDateTime,
  matchesShortcut,
  ordinal,
  shortcutFromEvent,
} from "./date-stamp";

const press = (code: string, key: string, mods: Partial<KeyboardEvent> = {}) =>
  ({
    code,
    key,
    ctrlKey: false,
    altKey: false,
    shiftKey: false,
    metaKey: false,
    ...mods,
  }) as KeyboardEvent;

describe("date stamps", () => {
  it("writes the date and the time with its offset", () => {
    const date = new Date(2026, 9, 27, 11, 23, 49);
    expect(formatDate(date)).toBe("Oct 27th 2026");
    expect(formatDate(date, "iso")).toBe("2026-10-27");
    const offset = -date.getTimezoneOffset();
    const sign = offset >= 0 ? "+" : "-";
    const hh = String(Math.trunc(Math.abs(offset) / 60)).padStart(2, "0");
    const mm = String(Math.abs(offset) % 60).padStart(2, "0");
    expect(formatDateTime(date)).toBe(`2026-10-27T11:23:49${sign}${hh}:${mm}`);
  });

  it("puts the right ending on the day", () => {
    const days = [1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 30, 31];
    expect(days.map(ordinal)).toEqual([
      "1st",
      "2nd",
      "3rd",
      "4th",
      "11th",
      "12th",
      "13th",
      "21st",
      "22nd",
      "23rd",
      "30th",
      "31st",
    ]);
    expect(formatDate(new Date(2026, 0, 1))).toBe("Jan 1st 2026");
  });

  it("matches Ctrl+; and Ctrl+Shift+; by the key, not the character", () => {
    const plain = press("Semicolon", ";", { ctrlKey: true });
    // Shift turns ";" into ":" on a US keyboard; it's still the same key.
    const shifted = press("Semicolon", ":", { ctrlKey: true, shiftKey: true });
    expect(matchesShortcut(plain, DEFAULT_DATE_SHORTCUT)).toBe(true);
    expect(matchesShortcut(shifted, DEFAULT_DATE_SHORTCUT)).toBe(false);
    expect(matchesShortcut(shifted, DEFAULT_DATE_TIME_SHORTCUT)).toBe(true);
  });

  it("records a pressed shortcut with a readable name", () => {
    expect(
      shortcutFromEvent(press("KeyD", "d", { altKey: true, shiftKey: true })),
    ).toMatchObject({ code: "KeyD", label: "Alt+Shift+D" });
    expect(
      shortcutFromEvent(
        press("Semicolon", ":", { ctrlKey: true, shiftKey: true }),
      )?.label,
    ).toBe("Ctrl+Shift+;");
    // A lone modifier, or a key that would just type, isn't a shortcut.
    expect(shortcutFromEvent(press("ShiftLeft", "Shift"))).toBeNull();
    expect(shortcutFromEvent(press("KeyD", "d"))).toBeNull();
  });
});
