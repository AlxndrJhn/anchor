import { describe, expect, it } from "vitest";
import { type GoToTarget, matchTargets } from "./go-to";

const page = (name: string): GoToTarget => ({
  id: `page:${name}`,
  name,
  href: `/${name.toLowerCase()}`,
  isTag: false,
});
const tag = (name: string): GoToTarget => ({
  id: `tag:${name}`,
  name,
  href: `/notes?tagId=${name}`,
  isTag: true,
});

const targets = [
  page("Notes"),
  page("Archive"),
  page("Trash"),
  tag("workout"),
  tag("work"),
  tag("home-work"),
  tag("tag1"),
  tag("tag5"),
];
const names = (query: string) =>
  matchTargets(targets, query).map((t) => t.name);

describe("matchTargets", () => {
  it("puts the whole name first, then its start, a word's start, anywhere", () => {
    expect(names("work")).toEqual(["work", "workout", "home-work"]);
    expect(names("ar")).toEqual(["Archive"]);
    expect(names("rk")).toEqual(["workout", "work", "home-work"]);
  });

  it("ignores case", () => {
    expect(names("TRASH")).toEqual(["Trash"]);
  });

  it("finds one tag from a single letter or digit", () => {
    expect(names("5")).toEqual(["tag5"]);
  });

  it("finds only tags after a #", () => {
    expect(names("#a")).toEqual(["tag1", "tag5"]);
    expect(names("#")).toEqual(["workout", "work", "home-work", "tag1", "tag5"]);
  });

  it("finds nothing for an empty query", () => {
    expect(names("  ")).toEqual([]);
  });
});
