import { describe, expect, it } from "vitest";
import {
  firstDayOfWeek,
  formatFullDate,
  formatLongDate,
  formatLongShortDate,
  formatShortDate,
  formatTime,
  formatWeekdayDate,
  resolveDateDisplay,
  uses12HourClock,
} from "./date-time";

const day = new Date(2026, 8, 30, 16, 5);

describe("date formats", () => {
  it.each([
    ["mdy", "Sep 30", "Sep 30, 2026", "September 30, 2026"],
    ["dmy", "30 Sep", "30 Sep 2026", "30 September 2026"],
    ["mdy-slash", "09/30", "09/30/2026", "09/30/2026"],
    ["dmy-slash", "30/09", "30/09/2026", "30/09/2026"],
    ["dmy-dot", "30.09.", "30.09.2026", "30.09.2026"],
    ["iso", "09-30", "2026-09-30", "2026-09-30"],
  ] as const)("reads %s", (display, short, full, long) => {
    expect(formatShortDate(day, display)).toBe(short);
    expect(formatFullDate(day, display)).toBe(full);
    expect(formatLongDate(day, display)).toBe(long);
    expect(formatWeekdayDate(day, display)).toBe(`Wed, ${short}`);
  });

  it("spells the month out without the year when the format has words", () => {
    expect(formatLongShortDate(day, "dmy")).toBe("30 September");
    expect(formatLongShortDate(day, "iso")).toBe("09-30");
  });

  it("follows the order of the browser's language when automatic", () => {
    expect(resolveDateDisplay("auto", "en-US")).toBe("mdy");
    expect(resolveDateDisplay("auto", "de-DE")).toBe("dmy");
    expect(resolveDateDisplay("auto", "sv-SE")).toBe("iso");
    expect(resolveDateDisplay("dmy-dot", "en-US")).toBe("dmy-dot");
  });
});

describe("clock", () => {
  it("reads 12 or 24 hours as chosen", () => {
    expect(formatTime(day, "12h")).toBe("4:05 PM");
    expect(formatTime(day, "24h")).toBe("16:05");
    expect(formatTime(new Date(2026, 8, 30, 9, 0), "24h")).toBe("09:00");
    expect(formatTime(new Date(2026, 8, 30, 0, 30), "12h")).toBe("12:30 AM");
  });

  it("follows the browser's language when automatic", () => {
    expect(uses12HourClock("auto", "en-US")).toBe(true);
    expect(uses12HourClock("auto", "de-DE")).toBe(false);
    expect(uses12HourClock("24h", "en-US")).toBe(false);
    expect(uses12HourClock("12h", "de-DE")).toBe(true);
  });
});

describe("firstDayOfWeek", () => {
  it("gives the chosen day", () => {
    expect(firstDayOfWeek("monday", "en-US")).toBe(1);
    expect(firstDayOfWeek("saturday", "en-US")).toBe(6);
    expect(firstDayOfWeek("sunday", "de-DE")).toBe(0);
  });

  it("follows the browser's language when automatic", () => {
    expect(firstDayOfWeek("auto", "en-US")).toBe(0);
    expect(firstDayOfWeek("auto", "de-DE")).toBe(1);
  });
});
