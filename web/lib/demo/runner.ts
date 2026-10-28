// Plays a feature demo on the real app: a pointer moves to each control and
// clicks it, and text is typed in, through the same DOM events a person's
// clicks and keys send.

/** A control on screen: its accessible name, its text, or a selector. */
export type Target =
  | string
  | {
      label?: string;
      text?: string;
      css?: string;
      /** Only inside the element this selector finds. */
      within?: string;
      /** Which one, when several match; the first by default. */
      nth?: number;
    };

export type Step =
  /** Shows a caption. */
  | { say: string }
  | { click: Target; say?: string }
  | { hover: Target; say?: string }
  /** Types into the target, or where the caret is. */
  | { type: string; into?: Target; say?: string }
  | { key: string; shift?: boolean; ctrl?: boolean }
  | { go: string; say?: string }
  | { wait: number }
  | { waitFor: Target }
  /** Anything else the app needs, e.g. a drag. */
  | { run: (play: Play) => Promise<void> | void; say?: string };

export interface Play {
  /** Throws once the demo is stopped. */
  check: () => void;
  find: (target: Target, timeout?: number) => Promise<HTMLElement>;
  moveTo: (element: Element) => Promise<void>;
  pause: (ms: number) => Promise<void>;
  say: (text: string) => void;
  go: (path: string) => void;
  cursor: (x: number, y: number, pressed?: boolean) => void;
}

export class Stopped extends Error {}

const CONTROLS =
  "button, a, input, textarea, select, label, summary, [role=button], [role=menuitem], [role=menuitemradio], [role=menuitemcheckbox], [role=option], [role=tab], [role=switch], [role=checkbox], [role=radio], [contenteditable=true], [aria-label]";

const normalize = (text: string | null | undefined) =>
  (text ?? "").replace(/\s+/g, " ").trim();

function isShown(element: Element) {
  if (element.closest("[data-demo-player]")) return false;
  const box = element.getBoundingClientRect();
  if (box.width === 0 || box.height === 0) return false;
  const style = getComputedStyle(element);
  return style.visibility !== "hidden" && style.display !== "none";
}

function matches(target: Target): HTMLElement[] {
  const spec = typeof target === "string" ? { label: target } : target;
  const roots = spec.within
    ? Array.from(document.querySelectorAll(spec.within))
    : [document];
  const found: HTMLElement[] = [];
  for (const root of roots) {
    const candidates = Array.from(
      root.querySelectorAll<HTMLElement>(spec.css ?? CONTROLS),
    );
    for (const element of candidates) {
      if (!isShown(element)) continue;
      if (spec.label !== undefined) {
        const label =
          element.getAttribute("aria-label") ?? element.getAttribute("title");
        if (normalize(label) !== spec.label) {
          // A plain string also matches a control's own text.
          if (typeof target !== "string") continue;
          if (normalize(element.textContent) !== spec.label) continue;
        }
      }
      if (
        spec.text !== undefined &&
        normalize(element.textContent) !== spec.text
      )
        continue;
      found.push(element);
    }
  }
  // The innermost control that matches, not the ones around it.
  return found.filter(
    (element) =>
      !found.some((other) => other !== element && element.contains(other)),
  );
}

export function describe(target: Target) {
  return typeof target === "string" ? target : JSON.stringify(target);
}

export async function findTarget(
  target: Target,
  check: () => void,
  timeout = 6000,
): Promise<HTMLElement> {
  const until = Date.now() + timeout;
  const nth = typeof target === "string" ? 0 : (target.nth ?? 0);
  for (;;) {
    check();
    const element = matches(target)[nth];
    if (element) return element;
    if (Date.now() > until) throw new Error(`Not found: ${describe(target)}`);
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

export function center(element: Element) {
  const box = element.getBoundingClientRect();
  return { x: box.left + box.width / 2, y: box.top + box.height / 2 };
}

/** The events a mouse click sends, in order. */
export function clickElement(element: HTMLElement) {
  const { x, y } = center(element);
  const init = {
    bubbles: true,
    cancelable: true,
    composed: true,
    clientX: x,
    clientY: y,
    button: 0,
    view: window,
  };
  const pointer = {
    ...init,
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  };
  element.dispatchEvent(new PointerEvent("pointerover", pointer));
  element.dispatchEvent(new PointerEvent("pointerenter", pointer));
  element.dispatchEvent(new MouseEvent("mouseover", init));
  element.dispatchEvent(
    new PointerEvent("pointerdown", { ...pointer, buttons: 1 }),
  );
  element.dispatchEvent(new MouseEvent("mousedown", { ...init, buttons: 1 }));
  if (element.matches("input, textarea, select, [contenteditable=true]"))
    element.focus();
  element.dispatchEvent(new PointerEvent("pointerup", pointer));
  element.dispatchEvent(new MouseEvent("mouseup", init));
  element.dispatchEvent(new MouseEvent("click", init));
}

export function hoverElement(element: HTMLElement) {
  const { x, y } = center(element);
  const init = { bubbles: true, clientX: x, clientY: y, view: window };
  element.dispatchEvent(
    new PointerEvent("pointerover", { ...init, pointerType: "mouse" }),
  );
  element.dispatchEvent(
    new PointerEvent("pointermove", { ...init, pointerType: "mouse" }),
  );
  element.dispatchEvent(new MouseEvent("mouseover", init));
  element.dispatchEvent(new MouseEvent("mousemove", init));
}

/** The events a mouse sends when it leaves an element. */
export function leaveElement(element: Element) {
  if (!element.isConnected) return;
  const init = { bubbles: true, view: window };
  const pointer = { ...init, pointerId: 1, pointerType: "mouse" };
  element.dispatchEvent(new PointerEvent("pointerout", pointer));
  element.dispatchEvent(
    new PointerEvent("pointerleave", { ...pointer, bubbles: false }),
  );
  element.dispatchEvent(new MouseEvent("mouseout", init));
  element.dispatchEvent(
    new MouseEvent("mouseleave", { ...init, bubbles: false }),
  );
}

export function pressKey(
  key: string,
  { shift = false, ctrl = false }: { shift?: boolean; ctrl?: boolean } = {},
) {
  const target =
    (document.activeElement as HTMLElement | null) ?? document.body;
  const init = {
    key,
    code: key.length === 1 ? `Key${key.toUpperCase()}` : key,
    bubbles: true,
    cancelable: true,
    shiftKey: shift,
    ctrlKey: ctrl,
  };
  const down = new KeyboardEvent("keydown", init);
  const handled = !target.dispatchEvent(down);
  target.dispatchEvent(new KeyboardEvent("keyup", init));
  return handled;
}

/** Types one character where the caret is, as a key press would. */
export function typeCharacter(character: string) {
  const element = document.activeElement as HTMLElement | null;
  if (!element) return;
  if (
    element instanceof HTMLInputElement ||
    element instanceof HTMLTextAreaElement
  ) {
    const proto =
      element instanceof HTMLTextAreaElement
        ? HTMLTextAreaElement.prototype
        : HTMLInputElement.prototype;
    const setValue = Object.getOwnPropertyDescriptor(proto, "value")?.set;
    const start = element.selectionStart ?? element.value.length;
    const end = element.selectionEnd ?? element.value.length;
    const value =
      element.value.slice(0, start) + character + element.value.slice(end);
    setValue?.call(element, value);
    element.setSelectionRange?.(start + 1, start + 1);
    element.dispatchEvent(
      new InputEvent("input", {
        bubbles: true,
        data: character,
        inputType: "insertText",
      }),
    );
    return;
  }
  if (character === "\n") {
    pressKey("Enter");
    return;
  }
  document.execCommand("insertText", false, character);
}

/** Puts the caret at the end of an editable element. */
export function caretToEnd(element: HTMLElement) {
  element.focus();
  if (
    element instanceof HTMLInputElement ||
    element instanceof HTMLTextAreaElement
  ) {
    element.setSelectionRange(element.value.length, element.value.length);
    return;
  }
  const range = document.createRange();
  range.selectNodeContents(element);
  range.collapse(false);
  const selection = window.getSelection();
  selection?.removeAllRanges();
  selection?.addRange(range);
}
