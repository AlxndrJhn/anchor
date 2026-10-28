/** A key combination, by physical key, so it works on any keyboard layout. */
export interface Shortcut {
  ctrl: boolean;
  alt: boolean;
  shift: boolean;
  meta: boolean;
  /** KeyboardEvent.code, e.g. "Semicolon". */
  code: string;
  /** How it reads, as recorded on this keyboard, e.g. "Ctrl+;". */
  label: string;
}

export const DEFAULT_DATE_SHORTCUT: Shortcut = {
  ctrl: true,
  alt: false,
  shift: false,
  meta: false,
  code: "Semicolon",
  label: "Ctrl+;",
};

export const DEFAULT_DATE_TIME_SHORTCUT: Shortcut = {
  ...DEFAULT_DATE_SHORTCUT,
  shift: true,
  label: "Ctrl+Shift+;",
};

/** How an inserted date reads: "Oct 28th 2026" or "2026-10-28". */
export type DateFormat = "long" | "iso";

export const DEFAULT_DATE_FORMAT: DateFormat = "long";

const pad = (n: number) => String(Math.abs(n)).padStart(2, "0");

const MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

const ENDINGS: Record<number, string> = { 1: "st", 2: "nd", 3: "rd" };

/** 1st, 2nd, 3rd, 4th … 11th, 12th, 13th … 21st. */
export function ordinal(n: number): string {
  const tens = n % 100;
  if (tens >= 11 && tens <= 13) return `${n}th`;
  return `${n}${ENDINGS[n % 10] ?? "th"}`;
}

/** Today's date, as on this device: "Oct 27th 2026", or "2026-10-27". */
export function formatDate(
  date: Date,
  format: DateFormat = DEFAULT_DATE_FORMAT,
): string {
  if (format === "long")
    return `${MONTHS[date.getMonth()]} ${ordinal(date.getDate())} ${date.getFullYear()}`;
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** The time with its offset from UTC: "2026-10-27T11:23:49+01:00". */
export function formatDateTime(date: Date): string {
  const offset = -date.getTimezoneOffset();
  const sign = offset >= 0 ? "+" : "-";
  return (
    `${formatDate(date, "iso")}T${pad(date.getHours())}:${pad(date.getMinutes())}:` +
    `${pad(date.getSeconds())}${sign}${pad(Math.trunc(offset / 60))}:${pad(offset % 60)}`
  );
}

type KeyLike = Pick<
  KeyboardEvent,
  "ctrlKey" | "altKey" | "shiftKey" | "metaKey" | "code" | "key"
>;

export function matchesShortcut(e: KeyLike, shortcut: Shortcut): boolean {
  return (
    e.code === shortcut.code &&
    e.ctrlKey === shortcut.ctrl &&
    e.altKey === shortcut.alt &&
    e.shiftKey === shortcut.shift &&
    e.metaKey === shortcut.meta
  );
}

const MODIFIER_KEYS = new Set(["Control", "Alt", "Shift", "Meta", "AltGraph"]);

/**
 * The shortcut a key press makes, for recording one in Settings; null for
 * a lone modifier or a key with no modifier (it would type instead).
 */
export function shortcutFromEvent(e: KeyLike): Shortcut | null {
  if (MODIFIER_KEYS.has(e.key) || !e.code) return null;
  if (!e.ctrlKey && !e.altKey && !e.metaKey) return null;
  const parts = [
    e.ctrlKey && "Ctrl",
    e.altKey && "Alt",
    e.shiftKey && "Shift",
    e.metaKey && "Meta",
  ].filter(Boolean);
  // With Shift held, key names the shifted character (":"), not the key.
  const base = e.code.startsWith("Key")
    ? e.code.slice(3)
    : e.code.startsWith("Digit")
      ? e.code.slice(5)
      : e.key.length === 1 && !e.shiftKey
        ? e.key
        : (CODE_NAMES[e.code] ?? e.code);
  return {
    ctrl: e.ctrlKey,
    alt: e.altKey,
    shift: e.shiftKey,
    meta: e.metaKey,
    code: e.code,
    label: [...parts, base].join("+"),
  };
}

const CODE_NAMES: Record<string, string> = {
  Semicolon: ";",
  Quote: "'",
  Comma: ",",
  Period: ".",
  Slash: "/",
  Backslash: "\\",
  BracketLeft: "[",
  BracketRight: "]",
  Minus: "-",
  Equal: "=",
  Backquote: "`",
};

/** The date or date and time a key press asks for, if any. */
export function stampFor(
  e: KeyLike,
  shortcuts: {
    dateShortcut?: Shortcut;
    dateTimeShortcut?: Shortcut;
    dateFormat?: DateFormat;
  },
  now = new Date(),
): string | null {
  if (
    matchesShortcut(e, shortcuts.dateTimeShortcut ?? DEFAULT_DATE_TIME_SHORTCUT)
  )
    return formatDateTime(now);
  if (matchesShortcut(e, shortcuts.dateShortcut ?? DEFAULT_DATE_SHORTCUT))
    return formatDate(now, shortcuts.dateFormat);
  return null;
}
