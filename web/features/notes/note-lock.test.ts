import { pbkdf2Sync, randomBytes } from "node:crypto";
import { beforeEach, describe, expect, it } from "vitest";
import {
  addPatternDot,
  isLockHidden,
  isValidPattern,
  isValidPin,
  lockableNotes,
  lockSecretMatches,
  patternDotAt,
  patternDotCentre,
  unlockMethod,
  useUnlockedNotes,
} from "./note-lock";
import type { NoteLockSecrets } from "./types";

// Hashed as the server does it.
const hash = (secret: string, iterations = 1000) => {
  const salt = randomBytes(16);
  const key = pbkdf2Sync(secret, salt, iterations, 32, "sha256");
  return `pbkdf2-sha256$${iterations}$${salt.toString("base64")}$${key.toString("base64")}`;
};

describe("the unlock session", () => {
  beforeEach(() => useUnlockedNotes.getState().endSession());

  it("keeps notes unlocked until it ends", () => {
    const note = { id: "a", lock: "pin" as const };
    expect(isLockHidden(note, useUnlockedNotes.getState().ids)).toBe(true);
    useUnlockedNotes.getState().unlock("a");
    expect(isLockHidden(note, useUnlockedNotes.getState().ids)).toBe(false);
    // Unlocking it again changes nothing.
    const before = useUnlockedNotes.getState().ids;
    useUnlockedNotes.getState().unlock("a");
    expect(useUnlockedNotes.getState().ids).toBe(before);
    useUnlockedNotes.getState().endSession();
    expect(isLockHidden(note, useUnlockedNotes.getState().ids)).toBe(true);
  });

  it("never hides a note without a lock", () => {
    expect(isLockHidden({ id: "b", lock: null }, new Set())).toBe(false);
    expect(isLockHidden({ id: "b" }, new Set())).toBe(false);
  });

  it("leaves notes still locked out of a selection's new lock", () => {
    const notes = [
      { id: "plain", lock: null },
      { id: "open", lock: "tap" as const },
      { id: "shut", lock: "pin" as const },
    ];
    const { lockable, skipped } = lockableNotes(notes, new Set(["open"]));
    expect(lockable.map((n) => n.id)).toEqual(["plain", "open"]);
    expect(skipped.map((n) => n.id)).toEqual(["shut"]);
  });
});

describe("unlockMethod on the web", () => {
  const secrets = (s: Partial<NoteLockSecrets>): NoteLockSecrets => ({
    pin: null,
    pattern: null,
    hasPassword: true,
    ...s,
  });

  it("asks for the password in place of a fingerprint", () => {
    expect(unlockMethod("biometric", secrets({}))).toBe("password");
    expect(unlockMethod("biometric", undefined)).toBe("password");
  });

  it("falls back to the PIN, the pattern, then a tap without a password", () => {
    const sso = { hasPassword: false };
    expect(unlockMethod("biometric", secrets({ ...sso, pin: "h" }))).toBe(
      "pin",
    );
    expect(unlockMethod("biometric", secrets({ ...sso, pattern: "h" }))).toBe(
      "pattern",
    );
    expect(unlockMethod("biometric", secrets(sso))).toBe("tap");
  });

  it("uses the PIN, pattern or tap the note is locked with", () => {
    const both = secrets({ pin: "h", pattern: "h" });
    expect(unlockMethod("pin", both)).toBe("pin");
    expect(unlockMethod("pattern", both)).toBe("pattern");
    expect(unlockMethod("tap", both)).toBe("tap");
  });
});

describe("PIN and pattern rules", () => {
  it("takes 4 to 12 digits for a PIN", () => {
    expect(isValidPin("1234")).toBe(true);
    expect(isValidPin("123")).toBe(false);
    expect(isValidPin("1234567890123")).toBe(false);
    expect(isValidPin("12a4")).toBe(false);
  });

  it("takes 4 or more different dots for a pattern", () => {
    expect(isValidPattern("03678")).toBe(true);
    expect(isValidPattern("012")).toBe(false);
    expect(isValidPattern("0120")).toBe(false);
    expect(isValidPattern("0129")).toBe(false);
  });
});

describe("drawing a pattern", () => {
  const draw = (...dots: number[]) =>
    dots.reduce(addPatternDot, [] as number[]);

  it("adds the dots passed over", () => {
    expect(draw(0, 3, 6, 7)).toEqual([0, 3, 6, 7]);
    expect(draw(0, 3, 4, 3)).toEqual([0, 3, 4]);
  });

  it("takes an unused dot a straight line crosses", () => {
    expect(draw(0, 2)).toEqual([0, 1, 2]);
    expect(draw(0, 8)).toEqual([0, 4, 8]);
    expect(draw(6, 0)).toEqual([6, 3, 0]);
    // A dot already used is jumped over.
    expect(draw(1, 0, 2)).toEqual([1, 0, 2]);
    // A knight's move crosses no dot.
    expect(draw(0, 5)).toEqual([0, 5]);
  });

  it("finds the dot under the pointer only near its middle", () => {
    for (let dot = 0; dot < 9; dot++) {
      const { x, y } = patternDotCentre(dot);
      expect(patternDotAt(x + 10, y - 10)).toBe(dot);
    }
    expect(patternDotAt(100, 100)).toBeNull();
    expect(patternDotAt(-5, 50)).toBeNull();
    expect(patternDotAt(305, 50)).toBeNull();
  });
});

describe("lockSecretMatches", () => {
  it("checks a secret against the server's hash", async () => {
    const stored = hash("2580");
    expect(await lockSecretMatches("2580", stored)).toBe(true);
    expect(await lockSecretMatches("2581", stored)).toBe(false);
    expect(await lockSecretMatches("2580", "bcrypt$x")).toBe(false);
  });
});
