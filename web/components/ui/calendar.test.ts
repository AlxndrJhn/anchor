import { describe, expect, it } from "vitest";
import { daysIntoWeek, weekdayLetters } from "./calendar";

describe("weekdayLetters", () => {
  it("starts from the chosen day", () => {
    expect(weekdayLetters(0).join("")).toBe("SMTWTFS");
    expect(weekdayLetters(1).join("")).toBe("MTWTFSS");
    expect(weekdayLetters(6).join("")).toBe("SSMTWTF");
  });
});

describe("daysIntoWeek", () => {
  // 1 November 2026 is a Sunday.
  const sunday = new Date(2026, 10, 1);
  const monday = new Date(2026, 10, 2);

  it("counts from the day the week starts on", () => {
    expect(daysIntoWeek(sunday, 0)).toBe(0);
    expect(daysIntoWeek(sunday, 1)).toBe(6);
    expect(daysIntoWeek(sunday, 6)).toBe(1);
    expect(daysIntoWeek(monday, 1)).toBe(0);
  });
});
